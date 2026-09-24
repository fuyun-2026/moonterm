// A runnable demonstration of the engine.
//
// Run with:
//
//     moon run cmd/main
//
// It feeds a stream of escape sequences to a terminal and prints the resulting
// screen three ways: as plain text, as HTML, and as the ANSI stream that would
// reproduce it. The last form is the interesting one — piping it into a real
// terminal shows the same screen, which is the round trip `render/` is tested
// on, made visible.
//
// This is a demonstration rather than a complete CLI. Reading an arbitrary byte
// stream from a file or a pty belongs to whoever embeds the engine, since that
// is where the input actually comes from.

///|
/// A stream that exercises a cross-section of the implementation: styling, the
/// three colour syntaxes, cursor addressing, wide characters, the erase
/// operations and a scroll region.
///
/// Every line begins with an explicit `CUP`. The stream is meant to be read
/// alongside the screen it produces, and absolute positioning makes each line
/// independent of how the previous one wrapped.
fn demo_stream() -> String {
  let sb = StringBuilder()
  sb.write_string(
    "\u{1b}[1;1H\u{1b}[1mbold\u{1b}[0m and \u{1b}[4munderlined\u{1b}[0m",
  )
  sb.write_string(
    "\u{1b}[2;1H\u{1b}[31mred\u{1b}[0m \u{1b}[42mgreen background\u{1b}[0m \u{1b}[38;5;208m256-colour\u{1b}[0m",
  )
  sb.write_string(
    "\u{1b}[3;1H\u{1b}[38;2;122;162;247mtruecolour #7aa2f7\u{1b}[0m",
  )
  sb.write_string(
    "\u{1b}[4;1Hwide characters take two cells: \u{4e2d}\u{6587}\u{6d4b}\u{8bd5}",
  )
  sb.write_string("\u{1b}[6;10Hplaced by CUP at row 6, column 10")
  // Write a line, then erase from the middle of it to the right margin.
  sb.write_string("\u{1b}[8;1HEL 0 erases from here: XXXXXXXXXXXXXXXXXXXXXX")
  sb.write_string("\u{1b}[8;24H\u{1b}[0K")
  // A scroll region, then enough line feeds inside it to push the first line out.
  sb.write_string("\u{1b}[9;11r\u{1b}[11;1Hinside the scroll region")
  sb.write_string("\r\npushed up one\r\npushed up two")
  sb.to_string()
}

///|
fn main {
  // Twelve rows rather than twenty-four: the whole screen fits on one page of
  // output, which makes the demo readable when it is pasted into a bug report.
  let t = @term.Terminal::new(12, 60)
  t.feed(@utf8.encode(demo_stream()))
  t.finish()

  println("=== plain text ===")
  println(t.screen_text())

  println("")
  println("=== screen size ===")
  let (rows, cols) = t.size()
  println("rows=" + rows.to_string() + " cols=" + cols.to_string())

  println("")
  println("=== cursor ===")
  let (x, y) = t.cursor()
  println("x=" + x.to_string() + " y=" + y.to_string())

  println("")
  println("=== html ===")
  println(@render.to_html(t, "#d4d4d4", "#1e1e1e"))

  println("")
  println("=== re-emitted as ANSI ===")
  println("(piping this into a real terminal reproduces the screen above)")
  println(@render.to_ansi(t))
}
