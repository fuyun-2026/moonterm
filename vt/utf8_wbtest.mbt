///|
/// The Unicode replacement character, built at runtime to keep the source
/// free of literal escape syntax in expectations.
fn rep() -> Char {
  let cp : Int = 0xFFFD
  cp.unsafe_to_char()
}

///|
/// Decode every byte, then flush, and return the characters as a string.
fn decode_all(bytes : Bytes) -> String {
  let d = Utf8Decoder::new()
  let sb = StringBuilder()
  for b in bytes {
    d.feed(b)
    drain(d, sb)
  }
  d.finish()
  drain(d, sb)
  sb.to_string()
}

///|
fn drain(d : Utf8Decoder, sb : StringBuilder) -> Unit {
  let mut more = true
  while more {
    match d.next() {
      Some(c) => sb.write_char(c)
      None => more = false
    }
  }
}

///|
fn r(n : Int) -> String {
  let sb = StringBuilder()
  let mut i = 0
  while i < n {
    sb.write_char(rep())
    i = i + 1
  }
  sb.to_string()
}

///|
test "ascii passes through" {
  inspect(decode_all(b"hi"), content="hi")
}

///|
test "two byte sequence" {
  inspect(decode_all(b"\xc3\xa9"), content="é")
}

///|
test "three byte sequence" {
  inspect(decode_all(b"\xe4\xb8\xad") == "中", content="true")
}

///|
test "four byte sequence" {
  inspect(decode_all(b"\xf0\x9f\x98\x80") == "😀", content="true")
}

///|
test "mixed text" {
  inspect(decode_all(b"a\xc3\xa9b\xe4\xb8\xadc") == "aéb中c", content="true")
}

///|
test "a code point split across two feeds decodes the same" {
  let bytes = b"\xe4\xb8\xad"
  let d = Utf8Decoder::new()
  let sb = StringBuilder()
  d.feed(bytes[0])
  drain(d, sb)
  inspect(sb.to_string(), content="")
  d.feed(bytes[1])
  drain(d, sb)
  inspect(sb.to_string(), content="")
  d.feed(bytes[2])
  drain(d, sb)
  inspect(sb.to_string() == "中", content="true")
}

///|
test "a split four byte sequence is not lost" {
  let bytes = b"\xf0\x9f\x98\x80"
  let mut i = 0
  let d = Utf8Decoder::new()
  let sb = StringBuilder()
  while i < bytes.length() {
    d.feed(bytes[i])
    drain(d, sb)
    i = i + 1
  }
  inspect(sb.to_string() == "😀", content="true")
}

///|
test "an overlong encoding is rejected byte by byte" {
  // C0 is not a legal lead byte, and 80 is not a legal start; both become
  // replacement characters rather than being folded into one.
  inspect(decode_all(b"\xc0\x80") == r(2), content="true")
}

///|
test "a surrogate half is rejected" {
  // ED A0 80 would decode to U+D800, which UTF-8 must never carry.
  inspect(decode_all(b"\xed\xa0\x80") == r(1), content="true")
}

///|
test "a code point past U+10FFFF is rejected" {
  inspect(decode_all(b"\xf4\x90\x80\x80") == r(1), content="true")
}

///|
test "a bad continuation restarts at the offending byte" {
  // E4 starts a three byte sequence; 41 cannot continue it, so the partial
  // sequence becomes one replacement and the 41 is decoded as 'A'.
  inspect(decode_all(b"\xe4\x41") == "\{rep()}A", content="true")
}

///|
test "a truncated sequence is reported on finish" {
  let d = Utf8Decoder::new()
  let sb = StringBuilder()
  d.feed(b'\xe4')
  d.feed(b'\xb8')
  drain(d, sb)
  inspect(sb.to_string(), content="")
  d.finish()
  drain(d, sb)
  inspect(sb.to_string() == r(1), content="true")
}

///|
test "is_pending tracks an unfinished code point" {
  let d = Utf8Decoder::new()
  inspect(d.is_pending(), content="false")
  d.feed(b'\xe4')
  inspect(d.is_pending(), content="true")
  d.feed(b'\xb8')
  d.feed(b'\xad')
  inspect(d.is_pending(), content="false")
}

///|
test "a lone continuation byte is replaced" {
  inspect(decode_all(b"\x80") == r(1), content="true")
}

///|
test "feeding one byte at a time matches feeding all at once" {
  let bytes = b"a\xc3\xa9\xe4\xb8\xad\xf0\x9f\x98\x80z"
  let expected = decode_all(bytes)
  let d = Utf8Decoder::new()
  let sb = StringBuilder()
  for b in bytes {
    d.feed(b)
    drain(d, sb)
  }
  d.finish()
  drain(d, sb)
  inspect(sb.to_string(), content=expected)
}
