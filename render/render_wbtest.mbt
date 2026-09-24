// Tests for the renderers.
//
// The centrepiece is the round trip: render a screen to ANSI, feed that stream
// back into a fresh terminal, and require the two screens to be identical. It
// catches a renderer that drops an attribute, emits operands in the wrong
// order, or trims a cell it should have kept — none of which a string
// comparison against a hand-written expectation would reliably notice.

///|
/// Feed `input` to a fresh terminal and return it.
fn term_of(rows : Int, cols : Int, input : Bytes) -> @term.Terminal {
  let t = @term.Terminal::new(rows, cols)
  t.feed(input)
  t.finish()
  t
}

///|
/// Render to ANSI, feed the result to a fresh terminal, and assert the screen
/// survives the trip.
///
/// Declared `raise` because `assert_eq` can fail; a plain `Unit` helper would
/// not be allowed to call it.
fn assert_round_trip(rows : Int, cols : Int, input : Bytes) -> Unit raise {
  let first = term_of(rows, cols, input)
  let second = term_of(rows, cols, to_ansi_bytes(first))
  assert_eq(second.screen_dump(), first.screen_dump())
}

///|
test "ansi round trip preserves plain text" {
  assert_round_trip(3, 20, b"\x68\x65\x6C\x6C\x6F")
}

///|
test "ansi round trip preserves cursor-relative layout" {
  assert_round_trip(
    5, 20, b"\x1B\x5B\x32\x3B\x35\x48\x61\x1B\x5B\x34\x3B\x31\x48\x62\x1B\x5B\x31\x3B\x31\x48\x63",
  )
}

///|
test "ansi round trip preserves wide characters" {
  // Two CJK characters, each two cells wide.
  assert_round_trip(3, 10, b"\xE4\xB8\xAD\xE6\x96\x87")
}

///|
test "ansi round trip preserves 256-colour and truecolour" {
  assert_round_trip(
    3, 24, b"\x1B\x5B\x33\x38\x3B\x35\x3B\x31\x39\x36\x6D\x78\x1B\x5B\x34\x38\x3B\x32\x3B\x31\x30\x3B\x32\x30\x3B\x33\x30\x6D\x79",
  )
}

///|
test "ansi round trip preserves attribute bits" {
  // Bold, italic and underline, then a reset back to plain.
  assert_round_trip(
    3, 20, b"\x1B\x5B\x31\x3B\x33\x3B\x34\x6D\x62\x1B\x5B\x30\x6D\x70",
  )
}

///|
test "ansi round trip preserves a background that fills a row" {
  // A background colour with no text must survive; trimming must not treat
  // these cells as empty.
  assert_round_trip(3, 12, b"\x1B\x5B\x34\x31\x6D\x20\x20\x20\x20\x20\x20")
}

///|
test "ansi emits a reset after styled output" {
  let t = term_of(3, 10, b"\x1B\x5B\x33\x31\x6D\x72\x65\x64")
  let stream = to_ansi(t)
  // The stream must not leave the pen dirty for whatever is rendered next.
  assert_true(stream.contains("\u{1b}[0m"))
}

///|
test "ansi output of a blank screen is empty" {
  let t = @term.Terminal::new(3, 10)
  assert_eq(to_ansi(t), "")
}

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

///|
test "default colour has no fixed rgb" {
  assert_true(color_to_rgb(@term.COLOR_DEFAULT) is None)
}

///|
test "palette colours use the xterm values" {
  assert_eq(color_to_rgb(@term.color_indexed(1)), Some((0xCD, 0x00, 0x00)))
  assert_eq(color_to_rgb(@term.color_indexed(15)), Some((0xFF, 0xFF, 0xFF)))
}

///|
test "colour cube corner is saturated red" {
  // Index 196 is the far corner of the 6x6x6 cube: red 255, green 0, blue 0.
  assert_eq(color_to_rgb(@term.color_indexed(196)), Some((255, 0, 0)))
}

///|
test "colour cube steps use the uneven levels" {
  // Index 16 is the cube origin, index 17 advances the blue channel to 95.
  assert_eq(color_to_rgb(@term.color_indexed(16)), Some((0, 0, 0)))
  assert_eq(color_to_rgb(@term.color_indexed(17)), Some((0, 0, 95)))
}

///|
test "greyscale ramp endpoints" {
  assert_eq(color_to_rgb(@term.color_indexed(232)), Some((8, 8, 8)))
  assert_eq(color_to_rgb(@term.color_indexed(255)), Some((238, 238, 238)))
}

///|
test "truecolour passes through unchanged" {
  assert_eq(color_to_rgb(@term.color_rgb(10, 20, 30)), Some((10, 20, 30)))
}

///|
test "css colour formats as hex and falls back when default" {
  assert_eq(css_color(@term.color_rgb(10, 20, 30), "none"), "#0a141e")
  assert_eq(css_color(@term.COLOR_DEFAULT, "inherit"), "inherit")
}

// ---------------------------------------------------------------------------
// HTML
// ---------------------------------------------------------------------------

///|
test "html markup carries a styled span" {
  let t = term_of(2, 10, b"\x1B\x5B\x33\x31\x6D\x72\x65\x64")
  let html = to_html(t, "#fff", "#000")
  assert_true(html.contains("color:#cd0000;"))
  assert_true(html.contains(">red</span>"))
}

///|
/// Count non-overlapping occurrences of `needle` in `haystack`.
fn count_of(haystack : String, needle : String) -> Int {
  let h = haystack.to_array()
  let n = needle.to_array()
  if n.length() == 0 || h.length() < n.length() {
    return 0
  }
  let mut count = 0
  let mut i = 0
  while i + n.length() <= h.length() {
    let mut j = 0
    while j < n.length() && h[i + j] == n[j] {
      j = j + 1
    }
    if j == n.length() {
      count = count + 1
      i = i + n.length()
    } else {
      i = i + 1
    }
  }
  count
}

///|
test "html merges a run of cells into one span" {
  // Five identically styled characters must not become five spans.
  let t = term_of(2, 10, b"\x1B\x5B\x34\x31\x6D\x61\x62\x63\x64\x65")
  let html = to_html(t, "#fff", "#000")
  assert_eq(count_of(html, "<span"), 1)
}

///|
test "html emits an unstyled span for default cells" {
  let t = term_of(2, 10, b"\x61\x62\x63")
  let html = to_html(t, "#fff", "#000")
  assert_true(html.contains("<span>abc</span>"))
}

///|
test "html trims trailing blank cells" {
  let t = term_of(2, 10, b"\x61")
  let html = to_html(t, "#fff", "#000")
  // Only the one character is emitted; nine trailing blanks produce no markup.
  assert_true(html.contains(">a</span>"))
  assert_false(html.contains(">a "))
}

///|
test "html escapes markup characters in output" {
  // A stream that prints < and > must not be able to inject markup.
  let t = term_of(2, 10, b"\x3C\x62\x3E\x26")
  let html = to_html(t, "#fff", "#000")
  assert_true(html.contains("&lt;b&gt;&amp;"))
  assert_false(html.contains("<b>"))
}

///|
test "escape_html covers the four significant characters" {
  assert_eq(escape_html("<>&\""), "&lt;&gt;&amp;&quot;")
}
