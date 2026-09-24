///|
/// Incremental UTF-8 decoder.
///
/// Terminal input arrives in arbitrary chunks, so a multi-byte code point can
/// be split across two `feed` calls. The decoder remembers the partially
/// assembled code point and how many continuation bytes it still expects, so
/// `feed` may be called with one byte at a time without losing state.
///
/// Invalid input follows Unicode's "maximal subpart" rule: the longest prefix
/// that cannot possibly become a valid sequence is emitted as U+FFFD, and the
/// byte that broke it is re-examined as the start of a new sequence.
pub struct Utf8Decoder {
  mut codepoint : Int
  mut remaining : Int
  mut min_codepoint : Int
  // A single byte can produce two characters (a replacement char followed by
  // the restart byte), so the output is a two-slot queue rather than a value.
  mut out0 : Char
  mut out1 : Char
  mut pending : Int
}

///|
/// The Unicode replacement character, emitted for malformed input.
fn replacement() -> Char {
  let cp : Int = 0xFFFD
  cp.unsafe_to_char()
}

///|
pub fn Utf8Decoder::new() -> Utf8Decoder {
  {
    codepoint: 0,
    remaining: 0,
    min_codepoint: 0,
    out0: ' ',
    out1: ' ',
    pending: 0,
  }
}

///|
fn Utf8Decoder::push(self : Utf8Decoder, c : Char) -> Unit {
  if self.pending == 0 {
    self.out0 = c
  } else {
    self.out1 = c
  }
  self.pending = self.pending + 1
}

///|
/// Feed a single byte. Decoded characters are queued; drain them with `next`.
pub fn Utf8Decoder::feed(self : Utf8Decoder, b : Byte) -> Unit {
  self.pending = 0
  let byte = b.to_int() & 0xFF
  let mut restart = true
  while restart {
    restart = false
    if self.remaining > 0 {
      if byte >= 0x80 && byte <= 0xBF {
        self.codepoint = (self.codepoint << 6) | (byte & 0x3F)
        self.remaining = self.remaining - 1
        if self.remaining == 0 {
          let cp = self.codepoint
          // Reject overlong encodings, UTF-16 surrogates and out-of-range
          // code points; all three are invalid UTF-8 even though the byte
          // structure looked well formed.
          let bad = cp < self.min_codepoint ||
            (cp >= 0xD800 && cp <= 0xDFFF) ||
            cp > 0x10FFFF
          if bad {
            self.push(replacement())
          } else {
            self.push(cp.unsafe_to_char())
          }
        }
      } else {
        self.push(replacement())
        self.codepoint = 0
        self.remaining = 0
        restart = true
      }
    } else if byte < 0x80 {
      self.push(byte.unsafe_to_char())
    } else if byte >= 0xC2 && byte <= 0xDF {
      self.codepoint = byte & 0x1F
      self.remaining = 1
      self.min_codepoint = 0x80
    } else if byte >= 0xE0 && byte <= 0xEF {
      self.codepoint = byte & 0x0F
      self.remaining = 2
      self.min_codepoint = 0x800
    } else if byte >= 0xF0 && byte <= 0xF4 {
      self.codepoint = byte & 0x07
      self.remaining = 3
      self.min_codepoint = 0x10000
    } else {
      // 0x80-0xC1 would be a continuation or an overlong lead, and
      // 0xF5-0xFF would encode past U+10FFFF. Neither can start a sequence.
      self.push(replacement())
    }
  }
}

///|
/// Pop the next decoded character, or `None` when the queue is empty.
pub fn Utf8Decoder::next(self : Utf8Decoder) -> Char? {
  if self.pending == 0 {
    return None
  }
  let c = self.out0
  self.out0 = self.out1
  self.pending = self.pending - 1
  Some(c)
}

///|
/// True while a code point is half decoded, i.e. the stream ended mid-sequence.
pub fn Utf8Decoder::is_pending(self : Utf8Decoder) -> Bool {
  self.remaining > 0
}

///|
/// Discard any half-decoded code point, reporting it as U+FFFD.
pub fn Utf8Decoder::finish(self : Utf8Decoder) -> Unit {
  if self.remaining > 0 {
    self.push(replacement())
    self.codepoint = 0
    self.remaining = 0
  }
}
