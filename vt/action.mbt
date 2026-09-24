///|
/// The actions the VT parser performs on its host, following the DEC ANSI
/// escape sequence parser state machine (Williams, "A parser for ANSI").
///
/// The parser owns no screen state at all: it turns a byte stream into these
/// five calls and nothing else. Everything a terminal *does* with a sequence
/// lives in the implementor, which makes the parser testable on its own.
/// MoonBit seals traits by default, so a downstream package cannot implement
/// this one unless it is explicitly opened.
pub(open) trait Handler {
  /// A printable character reached the screen.
  fn print(Self, Char) -> Unit
  /// A C0 control character: BEL, BS, HT, LF, VT, FF, CR, SO, SI.
  fn execute(Self, Byte) -> Unit
  /// A complete control sequence: `ESC [ <private> <params> <intermediates> <final>`.
  /// `private` is the private marker byte (`<`, `=`, `>`, `?`) or `0` when absent.
  fn csi_dispatch(Self, Byte, ArrayView[Int], ArrayView[Byte], Byte) -> Unit
  /// A complete escape sequence that is not a CSI: `ESC <intermediates> <final>`.
  fn esc_dispatch(Self, ArrayView[Byte], Byte) -> Unit
  /// A complete operating system command: `ESC ] <data> (BEL | ST)`.
  /// `data` is the raw payload; parameters are separated by `;`.
  fn osc_dispatch(Self, ArrayView[Byte]) -> Unit
}
