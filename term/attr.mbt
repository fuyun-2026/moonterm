///|
/// Packed colour representation stored inside a cell.
///
/// `-1` means "the terminal's own default". `0..=255` is a palette index.
/// Anything with the `COLOR_RGB` bit set is a 24-bit truecolour value.
///
/// Colours are packed into an `Int` on purpose: a MoonBit `struct` is a
/// reference, so storing an `Attr` object per cell would make every cell alias
/// the same attribute. Plain integers copy by value and keep cells independent.
pub const COLOR_DEFAULT : Int = -1

///|
/// Marks a packed colour as 24-bit RGB rather than a palette index.
pub const COLOR_RGB : Int = 0x01000000

///|
/// Mask selecting the 24 bits of an RGB colour.
pub const COLOR_RGB_MASK : Int = 0x00FFFFFF

///|
pub fn color_indexed(i : Int) -> Int {
  i & 0xFF
}

///|
pub fn color_rgb(r : Int, g : Int, b : Int) -> Int {
  COLOR_RGB | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF)
}

///|
pub fn color_is_rgb(c : Int) -> Bool {
  c >= 0 && (c & COLOR_RGB) != 0
}

///|
pub fn color_index_of(c : Int) -> Int {
  c & 0xFF
}

///|
pub fn color_red(c : Int) -> Int {
  (c >> 16) & 0xFF
}

///|
pub fn color_green(c : Int) -> Int {
  (c >> 8) & 0xFF
}

///|
pub fn color_blue(c : Int) -> Int {
  c & 0xFF
}

///|
/// The SGR attributes that are not colours, kept as a bitfield so a whole pen
/// state is a single `Int`.
pub const FLAG_BOLD : Int = 0x001

///|
pub const FLAG_DIM : Int = 0x002

///|
pub const FLAG_ITALIC : Int = 0x004

///|
pub const FLAG_UNDERLINE : Int = 0x008

///|
pub const FLAG_BLINK : Int = 0x010

///|
pub const FLAG_REVERSE : Int = 0x020

///|
pub const FLAG_HIDDEN : Int = 0x040

///|
pub const FLAG_STRIKE : Int = 0x080

///|
/// The leading half of a double-width character.
pub const FLAG_WIDE : Int = 0x100

///|
/// The trailing half of a double-width character. It holds no text of its own
/// and is overwritten together with its leader.
pub const FLAG_WIDE_TAIL : Int = 0x200

///|
/// The bits that carry SGR attributes, i.e. everything except the wide markers.
pub const FLAG_SGR_MASK : Int = 0x0FF

///|
pub fn is_wide_lead(flags : Int) -> Bool {
  (flags & FLAG_WIDE) != 0
}

///|
pub fn is_wide_tail(flags : Int) -> Bool {
  (flags & FLAG_WIDE_TAIL) != 0
}

///|
/// Display width of a character in terminal cells: 0 for combining marks and
/// controls, 2 for East Asian wide and most emoji, 1 otherwise.
///
/// This is a range-based approximation of Unicode's East Asian Width property.
/// It covers the ranges that real terminal output actually uses (CJK, Hangul,
/// fullwidth forms, emoji) without embedding the full generated table, which
/// would be several thousand entries.
pub fn char_width(ch : Char) -> Int {
  let c = ch.to_int()
  if c == 0 {
    return 0
  }
  if c < 0x20 || (c >= 0x7F && c < 0xA0) {
    return 0
  }
  // Combining marks and other zero-width formatting characters.
  if (c >= 0x0300 && c <= 0x036F) ||
    (c >= 0x0483 && c <= 0x0489) ||
    (c >= 0x0591 && c <= 0x05BD) ||
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    (c >= 0x0E31 && c <= 0x0E3A) ||
    (c >= 0x1AB0 && c <= 0x1AFF) ||
    (c >= 0x1DC0 && c <= 0x1DFF) ||
    (c >= 0x20D0 && c <= 0x20FF) ||
    (c >= 0xFE00 && c <= 0xFE0F) ||
    (c >= 0xFE20 && c <= 0xFE2F) ||
    c == 0x200B ||
    c == 0x200C ||
    c == 0x200D ||
    (c >= 0x200E && c <= 0x200F) ||
    c == 0xFEFF {
    return 0
  }
  // East Asian Wide and Fullwidth.
  if (c >= 0x1100 && c <= 0x115F) ||
    (c >= 0x2E80 && c <= 0x303E) ||
    (c >= 0x3041 && c <= 0x33FF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0xA000 && c <= 0xA4CF) ||
    (c >= 0xA960 && c <= 0xA97F) ||
    (c >= 0xAC00 && c <= 0xD7A3) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    (c >= 0xFE10 && c <= 0xFE19) ||
    (c >= 0xFE30 && c <= 0xFE6F) ||
    (c >= 0xFF00 && c <= 0xFF60) ||
    (c >= 0xFFE0 && c <= 0xFFE6) ||
    (c >= 0x1F300 && c <= 0x1F64F) ||
    (c >= 0x1F900 && c <= 0x1F9FF) ||
    (c >= 0x20000 && c <= 0x3FFFD) {
    return 2
  }
  1
}
