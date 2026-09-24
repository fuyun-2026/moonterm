///|
/// A handler that records every action as a short string, so a whole parse can
/// be asserted as one readable line.
struct Recorder {
  events : Array[String]
}

///|
fn Recorder::new() -> Recorder {
  { events: [], }
}

///|
fn Recorder::dump(self : Recorder) -> String {
  self.events.join("|")
}

///|
impl Handler for Recorder with fn print(self, ch) {
  self.events.push("P\{ch}")
}

///|
impl Handler for Recorder with fn execute(self, b) {
  self.events.push("E\{b.to_int() & 0xFF}")
}

///|
impl Handler for Recorder with fn csi_dispatch(self, marker, params, inter, f) {
  let sb = StringBuilder()
  sb.write_string("C")
  if marker != b'\x00' {
    let pc : Int = marker.to_int() & 0xFF
    sb.write_string("(")
    sb.write_char(pc.unsafe_to_char())
    sb.write_string(")")
  }
  sb.write_string("[")
  let mut first = true
  for p in params {
    if !first {
      sb.write_string(",")
    }
    sb.write_string("\{p}")
    first = false
  }
  sb.write_string("]")
  if inter.length() > 0 {
    sb.write_string("<i\{inter.length()}>")
  }
  sb.write_string("\{f.to_int() & 0xFF}")
  self.events.push(sb.to_string())
}

///|
impl Handler for Recorder with fn esc_dispatch(self, inter, f) {
  self.events.push("S<i\{inter.length()}>[\{f.to_int() & 0xFF}]")
}

///|
impl Handler for Recorder with fn osc_dispatch(self, data) {
  let sb = StringBuilder()
  for b in data {
    sb.write_char((b.to_int() & 0xFF).unsafe_to_char())
  }
  self.events.push("O[\{sb.to_string()}]")
}

///|
/// Parse `bytes` in one go and return the recorded trace.
fn trace(bytes : Bytes) -> String {
  let p = Parser::new()
  let r = Recorder::new()
  p.feed(r, bytes)
  p.finish(r)
  r.dump()
}

///|
/// Parse `bytes` in fixed-size chunks, to prove state survives chunk splits.
fn trace_chunked(bytes : Bytes, size : Int) -> String {
  let p = Parser::new()
  let r = Recorder::new()
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let end = if i + size < n { i + size } else { n }
    p.feed(r, bytes.exact_view(start=i, end~).to_owned())
    i = i + size
  }
  p.finish(r)
  r.dump()
}

///|
test "ground state prints ASCII" {
  inspect(trace(b"hi"), content="Ph|Pi")
}

///|
test "C0 controls are executed, not printed" {
  inspect(trace(b"a\r\nb"), content="Pa|E13|E10|Pb")
}

///|
test "DEL is discarded" {
  inspect(trace(b"a\x7fb"), content="Pa|Pb")
}

///|
test "CSI with parameters" {
  inspect(trace(b"\x1b[31m"), content="C[31]109")
}

///|
test "CSI with no parameters denotes a single zero" {
  inspect(trace(b"\x1b[m"), content="C[0]109")
}

///|
test "CSI with several parameters" {
  inspect(trace(b"\x1b[1;4;31m"), content="C[1,4,31]109")
}

///|
test "CSI with an empty parameter slot" {
  inspect(trace(b"\x1b[1;;3m"), content="C[1,0,3]109")
}

///|
test "CSI with a trailing semicolon keeps the empty slot" {
  inspect(trace(b"\x1b[1;m"), content="C[1,0]109")
}

///|
test "CSI private marker" {
  inspect(trace(b"\x1b[?25l"), content="C(?)[25]108")
}

///|
test "CSI intermediate bytes" {
  inspect(trace(b"\x1b[1 q"), content="C[1]<i1>113")
}

///|
test "ESC dispatch without intermediates" {
  inspect(trace(b"\x1bM"), content="S<i0>[77]")
}

///|
test "ESC dispatch with an intermediate" {
  inspect(trace(b"\x1b(B"), content="S<i1>[66]")
}

///|
test "OSC terminated by BEL" {
  inspect(trace(b"\x1b]0;title\x07"), content="O[0;title]")
}

///|
test "OSC terminated by string terminator" {
  inspect(trace(b"\x1b]0;title\x1b\\"), content="O[0;title]|S<i0>[92]")
}

///|
test "CSI with a subparameter is discarded whole" {
  inspect(trace(b"\x1b[38:2:255mX"), content="PX")
}

///|
test "DCS payload is swallowed, following text still prints" {
  inspect(trace(b"\x1bPq#0;2;0;0;0\x1b\\ok"), content="S<i0>[92]|Po|Pk")
}

///|
test "APC string is swallowed" {
  inspect(trace(b"\x1b_G a=T\x1b\\x"), content="S<i0>[92]|Px")
}

///|
test "many parameters are clamped, not corrupted" {
  let arr : Array[Byte] = [b'\x1b', b'[']
  let mut i = 0
  while i < 40 {
    arr.push(b'1')
    arr.push(b';')
    i = i + 1
  }
  arr.push(b'2')
  arr.push(b'm')
  let out = trace(Bytes::from_array(arr))
  // 41 values are present but the parser keeps at most 32, and it must keep
  // the *first* 32 rather than letting the tail overwrite them.
  let mut count = 1
  for ch in out {
    if ch == ',' {
      count = count + 1
    }
  }
  inspect(count, content="32")
  inspect(out.has_prefix("C[1,1,1,1,1,1,1,1"), content="true")
}

///|
test "an oversized parameter value saturates" {
  inspect(trace(b"\x1b[99999999999m"), content="C[65535]109")
}

///|
test "state survives being split between every byte" {
  let bytes = b"\x1b[1;31mhello\x1b]0;t\x07\x1b[0m"
  let whole = trace(bytes)
  let mut size = 1
  while size <= 4 {
    inspect(trace_chunked(bytes, size), content=whole)
    size = size + 1
  }
}

///|
test "C0 inside a CSI is still executed" {
  inspect(trace(b"\x1b[3\x08m"), content="E8|C[3]109")
}

///|
test "an interrupted CSI restarts cleanly" {
  inspect(trace(b"\x1b[1\x1b[2m"), content="C[2]109")
}

///|
test "ESC ESC is idempotent" {
  inspect(trace(b"\x1b\x1b[1m"), content="C[1]109")
}
