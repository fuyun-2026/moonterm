// The module's front door.
//
// Everything interesting lives in `vt`, `term` and `render`; this package exists
// so that `README.mbt.md` has somewhere to be checked, and so a caller who only
// wants a terminal does not have to know how the module is laid out.

///|
/// Build a terminal with `rows` lines and `cols` columns and the default
/// history size.
///
/// This is the entry point most callers want. Reach for `@term.Terminal`
/// directly when you need to control the scrollback capacity, and for the
/// `@vt` package when you want the escape-sequence parser without a screen.
pub fn new_terminal(rows : Int, cols : Int) -> @term.Terminal {
  @term.Terminal::new(rows, cols)
}
