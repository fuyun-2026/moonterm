// Browser-facing entry points.
//
// This package is the only part of the project that knows it is running in a
// browser, and even it does not touch the DOM: it exposes plain functions and
// returns strings, and a small amount of JavaScript in `web/index.html` moves
// those strings into the page. Keeping the boundary that thin means the demo
// needs no FFI bindings at all, and the engine stays testable without a browser.
//
// Build with:
//
//     moon build --target js
//
// and load the generated module from `index.html`.

///|
/// The terminal the page is driving.
///
/// A module-level binding holding a struct with a mutable field, rather than a
/// `let mut`, because MoonBit has no mutable top-level bindings. The demo drives
/// exactly one terminal, so one cell of state is enough; a host that needs
/// several would hold this in a map keyed by a handle.
struct Session {
  mut term : @term.Terminal
}

///|
/// Default screen size, matching a conventional terminal window.
const DEFAULT_ROWS : Int = 24

///|
/// Default screen width in columns.
const DEFAULT_COLS : Int = 80

///|
let session : Session = {
  term: @term.Terminal::new(DEFAULT_ROWS, DEFAULT_COLS),
}

///|
/// Read the current terminal.
fn term() -> @term.Terminal {
  session.term
}

///|
/// Entry point, required for the package to be built as a loadable JavaScript
/// module: MoonBit only emits JavaScript for executable packages, and library
/// packages are linked into whichever executable reaches them.
///
/// It deliberately does nothing. The page owns the lifecycle — it decides the
/// screen size, feeds the stream, and re-renders — so there is no work for a
/// module-load-time entry point to do.
fn main {

}

// ---------------------------------------------------------------------------
// Control
// ---------------------------------------------------------------------------

///|
/// Replace the terminal with a blank one of the given size.
pub fn term_new(rows : Int, cols : Int) -> Unit {
  session.term = @term.Terminal::new(rows, cols)
}

///|
/// Feed a chunk of terminal output.
///
/// Takes a `String` rather than bytes so the page can pass the contents of a
/// text box or a fetched fixture directly; the UTF-8 encoding happens here.
/// Chunks may be split anywhere, including mid-sequence and mid-character, so
/// the page can stream without buffering whole escape sequences itself.
pub fn term_feed_text(text : String) -> Unit {
  session.term.feed(@utf8.encode(text))
}

///|
/// Signal that the stream has ended, flushing any half-decoded character.
pub fn term_finish() -> Unit {
  session.term.finish()
}

///|
/// Reset to the power-on state, equivalent to `ESC c`.
pub fn term_reset() -> Unit {
  session.term.reset()
}

// ---------------------------------------------------------------------------
// Reading the screen back
// ---------------------------------------------------------------------------

///|
/// The screen as HTML: one `<div>` per row, ready to assign to `innerHTML`.
pub fn term_screen_html() -> String {
  // Defaults chosen to match the page's own colours, so a cell using the
  // terminal default inherits them instead of being painted explicitly.
  @render.to_html(term(), "#d4d4d4", "#1e1e1e")
}

///|
/// The screen as plain text, trailing blanks trimmed, one line per row.
pub fn term_screen_text() -> String {
  term().screen_text()
}

///|
/// Everything the user could reach by scrolling up, oldest line first.
pub fn term_scrollback_text() -> String {
  term().scrollback_dump()
}

///|
/// How many lines of history have accumulated.
pub fn term_scrollback_len() -> Int {
  term().scrollback_len()
}

///|
/// The window title set by `OSC 0` or `OSC 2`, or the empty string.
pub fn term_title() -> String {
  term().title_text()
}

///|
/// The cursor position as `"x,y"`, both zero-based.
///
/// Returned as a string because that is what the page wants for a status line;
/// a host doing something more interesting would want the pair, but exposing a
/// tuple across the JavaScript boundary costs more than it is worth here.
pub fn term_cursor() -> String {
  let (x, y) = term().cursor()
  x.to_string() + "," + y.to_string()
}

///|
/// Whether the alternate screen is active.
pub fn term_is_alt() -> Bool {
  term().is_on_alt()
}

///|
/// Screen size as `"rows,cols"`.
pub fn term_size() -> String {
  let (rows, cols) = term().size()
  rows.to_string() + "," + cols.to_string()
}

///|
/// The screen rendered back to ANSI, which lets the page hand the current
/// screen to a real terminal or save it to a file.
pub fn term_ansi() -> String {
  @render.to_ansi(term())
}
