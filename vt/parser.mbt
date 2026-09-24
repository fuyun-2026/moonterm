///|
/// Maximum number of parameters kept for one control sequence. The DEC
/// specification allows 16; xterm and friends accept 32, and real programs do
/// occasionally emit long SGR runs, so 32 is the safer ceiling. Further
/// parameters are dropped rather than corrupting the ones already collected.
const MAX_PARAMS : Int = 32

///|
/// Largest parameter value we will accumulate. Values past this have no
/// meaning for any sequence we implement, and xterm uses the same bound.
const MAX_PARAM_VALUE : Int = 65535

///|
/// Maximum number of intermediate bytes. The specification permits exactly two
/// (`0x20`-`0x2F`), e.g. `ESC ( B` or `ESC # 8`.
const MAX_INTERMEDIATES : Int = 2

///|
/// Maximum length of an OSC payload we will buffer. Payloads are usually a
/// title or a colour report; the cap stops a hostile stream from growing the
/// buffer without bound.
const MAX_OSC : Int = 4096

///|
/// Parser states, exactly as named in the DEC ANSI parser specification.
pub enum State {
  Ground
  Escape
  EscapeIntermediate
  CsiEntry
  CsiParam
  CsiIntermediate
  CsiIgnore
  DcsEntry
  DcsParam
  DcsIntermediate
  DcsPassthrough
  DcsIgnore
  OscString
  SosPmApcString
}

///|
/// A byte-stream parser for ANSI/VT escape sequences.
///
/// This is a pure transducer: bytes in, `Handler` calls out. It holds no screen
/// state, so it can be tested against the specification tables directly.
pub struct Parser {
  mut state : State
  decoder : Utf8Decoder
  params : Array[Int]
  mut num_params : Int
  mut current_param : Int
  mut param_started : Bool
  intermediates : Array[Byte]
  mut num_intermediates : Int
  mut private_marker : Byte
  osc_buf : Array[Byte]
  mut num_osc : Int
}

///|
pub fn Parser::new() -> Parser {
  {
    state: State::Ground,
    decoder: Utf8Decoder::new(),
    params: Array::make(MAX_PARAMS, 0),
    num_params: 0,
    current_param: 0,
    param_started: false,
    intermediates: Array::make(MAX_INTERMEDIATES, b'\x00'),
    num_intermediates: 0,
    private_marker: b'\x00',
    osc_buf: Array::make(MAX_OSC, b'\x00'),
    num_osc: 0,
  }
}

///|
/// Discard everything collected for the sequence that just ended.
fn Parser::clear(self : Parser) -> Unit {
  self.num_params = 0
  self.current_param = 0
  self.param_started = false
  self.num_intermediates = 0
  self.private_marker = b'\x00'
}

///|
/// Accumulate one digit of the parameter currently being read.
fn Parser::digit(self : Parser, c : Int) -> Unit {
  let d = c - 0x30
  if self.param_started {
    // Clamp rather than wrap. Wrapping would turn an absurd parameter into a
    // plausible-looking small one, which is far worse than saturating.
    if self.current_param > (MAX_PARAM_VALUE - d) / 10 {
      self.current_param = MAX_PARAM_VALUE
    } else {
      self.current_param = self.current_param * 10 + d
    }
  } else {
    self.current_param = d
    self.param_started = true
  }
}

///|
/// Finish the parameter currently being read and start the next one.
fn Parser::push_param(self : Parser) -> Unit {
  if self.num_params < MAX_PARAMS {
    let value = if self.param_started { self.current_param } else { 0 }
    self.params[self.num_params] = value
    self.num_params = self.num_params + 1
  }
  self.current_param = 0
  self.param_started = false
}

///|
fn Parser::collect(self : Parser, b : Byte) -> Unit {
  if self.num_intermediates < MAX_INTERMEDIATES {
    self.intermediates[self.num_intermediates] = b
    self.num_intermediates = self.num_intermediates + 1
  }
}

///|
fn Parser::set_private(self : Parser, b : Byte) -> Unit {
  if self.private_marker == b'\x00' {
    self.private_marker = b
  }
}

///|
fn Parser::put_osc(self : Parser, b : Byte) -> Unit {
  if self.num_osc < MAX_OSC {
    self.osc_buf[self.num_osc] = b
    self.num_osc = self.num_osc + 1
  }
}

///|
fn[H : Handler] Parser::dispatch_csi(
  self : Parser,
  h : H,
  final_byte : Byte,
) -> Unit {
  // A sequence with no parameters at all still denotes a single zero
  // parameter: `CSI m` is `SGR 0`, and `CSI A` is `CUU 1`.
  self.push_param()
  let params = self.params.exact_view(start=0, end=self.num_params)
  let inter = self.intermediates.exact_view(start=0, end=self.num_intermediates)
  h.csi_dispatch(self.private_marker, params, inter, final_byte)
}

///|
fn[H : Handler] Parser::dispatch_esc(
  self : Parser,
  h : H,
  final_byte : Byte,
) -> Unit {
  let inter = self.intermediates.exact_view(start=0, end=self.num_intermediates)
  h.esc_dispatch(inter, final_byte)
}

///|
fn[H : Handler] Parser::dispatch_osc(self : Parser, h : H) -> Unit {
  let data = self.osc_buf.exact_view(start=0, end=self.num_osc)
  h.osc_dispatch(data)
}

///|
fn[H : Handler] Parser::ground(self : Parser, h : H, b : Byte, c : Int) -> Unit {
  if c == 0x1B {
    self.state = State::Escape
  } else if c < 0x20 {
    h.execute(b)
  } else if c == 0x7F {
    // DEL is discarded in the ground state, as on a real terminal.
  } else {
    self.decoder.feed(b)
    let mut more = true
    while more {
      match self.decoder.next() {
        Some(ch) => h.print(ch)
        None => more = false
      }
    }
  }
}

///|
/// Feed a chunk of bytes through the parser, emitting actions to `h`.
///
/// Chunks may be split anywhere, including in the middle of an escape sequence
/// or in the middle of a UTF-8 code point; parser state persists across calls.
pub fn[H : Handler] Parser::feed(self : Parser, h : H, bytes : Bytes) -> Unit {
  for b in bytes {
    let c = b.to_int() & 0xFF
    match self.state {
      State::Ground => self.ground(h, b, c)
      State::Escape =>
        if c == 0x1B {
          self.state = State::Escape
          self.clear()
        } else if c < 0x20 {
          h.execute(b)
        } else if c == 0x7F {
          // ignore
        } else if c >= 0x20 && c <= 0x2F {
          self.clear()
          self.collect(b)
          self.state = State::EscapeIntermediate
        } else if c == 0x50 {
          self.clear()
          self.state = State::DcsEntry
        } else if c == 0x58 || c == 0x5E || c == 0x5F {
          self.state = State::SosPmApcString
        } else if c == 0x5B {
          self.clear()
          self.state = State::CsiEntry
        } else if c == 0x5D {
          self.clear()
          self.num_osc = 0
          self.state = State::OscString
        } else {
          self.clear()
          self.dispatch_esc(h, b)
          self.state = State::Ground
        }
      State::EscapeIntermediate =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c == 0x7F {
          // ignore
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
        } else {
          self.dispatch_esc(h, b)
          self.state = State::Ground
        }
      State::CsiEntry =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c == 0x7F {
          // ignore
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
          self.state = State::CsiIntermediate
        } else if c >= 0x30 && c <= 0x39 {
          self.digit(c)
          self.state = State::CsiParam
        } else if c == 0x3B {
          self.push_param()
          self.state = State::CsiParam
        } else if c == 0x3A {
          self.state = State::CsiIgnore
        } else if c >= 0x3C && c <= 0x3F {
          // The DEC table sends these bytes through the collect action, but
          // we surface the private marker as its own argument instead. Putting
          // it in both places would make every handler check for it twice.
          self.set_private(b)
          self.state = State::CsiParam
        } else {
          self.dispatch_csi(h, b)
          self.state = State::Ground
        }
      State::CsiParam =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c == 0x7F {
          // ignore
        } else if c >= 0x30 && c <= 0x39 {
          self.digit(c)
        } else if c == 0x3B {
          self.push_param()
        } else if c == 0x3A || (c >= 0x3C && c <= 0x3F) {
          // Sub-parameters (`:`) and a private marker appearing after a
          // digit are both malformed here; the whole sequence is discarded.
          self.state = State::CsiIgnore
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
          self.state = State::CsiIntermediate
        } else if c >= 0x40 && c <= 0x7E {
          self.dispatch_csi(h, b)
          self.state = State::Ground
        } else {
          self.state = State::CsiIgnore
        }
      State::CsiIntermediate =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c == 0x7F {
          // ignore
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
        } else if c >= 0x40 && c <= 0x7E {
          self.dispatch_csi(h, b)
          self.state = State::Ground
        } else {
          self.state = State::CsiIgnore
        }
      State::CsiIgnore =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c >= 0x40 && c <= 0x7E {
          // The sequence is dropped whole, but it still ends here.
          self.state = State::Ground
        } else {
          // stay in CsiIgnore
        }
      State::OscString =>
        if c == 0x07 {
          self.dispatch_osc(h)
          self.state = State::Ground
        } else if c == 0x1B {
          // String Terminator (ESC \) — deliver what we have and let the
          // Escape state swallow the backslash.
          self.dispatch_osc(h)
          self.state = State::Escape
        } else {
          self.put_osc(b)
        }
      // Device control strings are parsed for correct framing but their
      // payload is not acted on yet, so the three entry states below only
      // differ in which byte classes they accept.
      State::DcsEntry =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if (c >= 0x30 && c <= 0x39) || c == 0x3B {
          self.digit(c)
          self.state = State::DcsParam
        } else if c >= 0x3C && c <= 0x3F {
          self.set_private(b)
          self.state = State::DcsParam
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
          self.state = State::DcsIntermediate
        } else if c >= 0x40 && c <= 0x7E {
          self.state = State::DcsPassthrough
        } else {
          self.state = State::DcsIgnore
        }
      State::DcsParam =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if (c >= 0x30 && c <= 0x39) || c == 0x3B {
          self.digit(c)
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
          self.state = State::DcsIntermediate
        } else if c >= 0x40 && c <= 0x7E {
          self.state = State::DcsPassthrough
        } else {
          self.state = State::DcsIgnore
        }
      State::DcsIntermediate =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else if c >= 0x20 && c <= 0x2F {
          self.collect(b)
        } else if c >= 0x40 && c <= 0x7E {
          self.state = State::DcsPassthrough
        } else {
          self.state = State::DcsIgnore
        }
      State::DcsPassthrough | State::DcsIgnore =>
        if c == 0x1B {
          self.clear()
          self.state = State::Escape
        } else if c < 0x20 {
          h.execute(b)
        } else {
          // payload is discarded
        }
      State::SosPmApcString =>
        if c == 0x1B {
          self.state = State::Escape
        } else {
          // payload is discarded
        }
    }
  }
}

///|
/// Signal end of input. A trailing partial UTF-8 sequence is reported as
/// U+FFFD so the screen does not silently swallow it.
pub fn[H : Handler] Parser::finish(self : Parser, h : H) -> Unit {
  self.decoder.finish()
  let mut more = true
  while more {
    match self.decoder.next() {
      Some(ch) => h.print(ch)
      None => more = false
    }
  }
}
