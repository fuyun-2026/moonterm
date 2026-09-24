// Renderers: turn a `Terminal`'s cell grid into something a person can look at.
//
// The terminal itself only stores cells. Keeping the output formats out here
// means the engine stays free of any dependency on a display technology, and a
// new format (SVG, an image, a test fixture) can be added without touching the
// parser or the screen model.

///|
/// ESC, written as a code point rather than a literal byte so the source file
/// stays plain ASCII.
const ESC : String = "\u{1b}"

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

///|
/// The sixteen ANSI palette colours as `0xRRGGBB`, using xterm's default
/// values. Indices 8-15 are the bright variants.
///
/// A function rather than a `const` array: MoonBit constants must be immutable
/// primitives, so an array cannot be one. The match compiles to a jump table,
/// which costs less than the allocation a literal array would need.
fn palette16(i : Int) -> Int {
  if i == 0 {
    0x000000
  } else if i == 1 {
    0xCD0000
  } else if i == 2 {
    0x00CD00
  } else if i == 3 {
    0xCDCD00
  } else if i == 4 {
    0x0000EE
  } else if i == 5 {
    0xCD00CD
  } else if i == 6 {
    0x00CDCD
  } else if i == 7 {
    0xE5E5E5
  } else if i == 8 {
    0x7F7F7F
  } else if i == 9 {
    0xFF0000
  } else if i == 10 {
    0x00FF00
  } else if i == 11 {
    0xFFFF00
  } else if i == 12 {
    0x5C5CFF
  } else if i == 13 {
    0xFF00FF
  } else if i == 14 {
    0x00FFFF
  } else {
    0xFFFFFF
  }
}

///|
/// One channel of the 6x6x6 colour cube: the six levels a channel can take.
fn cube_step(n : Int) -> Int {
  if n == 0 {
    0
  } else if n == 1 {
    95
  } else if n == 2 {
    135
  } else if n == 3 {
    175
  } else if n == 4 {
    215
  } else {
    255
  }
}

///|
/// Resolve a packed cell colour to 8-bit RGB.
///
/// Returns `None` for the terminal default, which has no fixed colour: it means
/// "whatever the user's theme says", so a renderer must decide it for itself
/// rather than being told.
pub fn color_to_rgb(c : Int) -> (Int, Int, Int)? {
  if c < 0 {
    return None
  }
  if @term.color_is_rgb(c) {
    return Some((@term.color_red(c), @term.color_green(c), @term.color_blue(c)))
  }
  let i = @term.color_index_of(c)
  if i < 16 {
    let v = palette16(i)
    return Some(((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF))
  }
  if i < 232 {
    // The 6x6x6 colour cube. Each channel steps through 0, 95, 135, 175, 215,
    // 255 rather than an even division of the byte range.
    let n = i - 16
    let r = cube_step(n / 36)
    let g = cube_step(n / 6 % 6)
    let b = cube_step(n % 6)
    return Some((r, g, b))
  }
  // The final 24 entries are a greyscale ramp from 8 to 238.
  let level = 8 + (i - 232) * 10
  Some((level, level, level))
}

///|
/// Render a packed colour as a CSS `#rrggbb` string, or `fallback` when the
/// colour is the terminal default.
pub fn css_color(c : Int, fallback : String) -> String {
  match color_to_rgb(c) {
    None => fallback
    Some(rgb) => {
      let (r, g, b) = rgb
      "#" + hex2(r) + hex2(g) + hex2(b)
    }
  }
}

///|
/// Two lowercase hex digits. Written out rather than pulled from a formatting
/// library so the renderer has no dependency beyond the engine.
fn hex2(v : Int) -> String {
  let digits = "0123456789abcdef"
  let hi = (v >> 4) & 0xF
  let lo = v & 0xF
  let sb = StringBuilder()
  sb.write_char(digits[hi].unsafe_to_char())
  sb.write_char(digits[lo].unsafe_to_char())
  sb.to_string()
}

// ---------------------------------------------------------------------------
// ANSI
// ---------------------------------------------------------------------------

///|
/// The SGR sequence that selects exactly `fg`, `bg` and `flags`.
///
/// This always emits a full `CSI 0 m` reset followed by every attribute that is
/// set, rather than computing a minimal delta from the previous pen. A reset
/// makes the sequence correct on its own, which matters because the renderer
/// also emits a reset at the end of every row: output is then safe to
/// concatenate, redirect to a file, or splice into another stream.
fn sgr_for(fg : Int, bg : Int, flags : Int) -> String {
  let sb = StringBuilder()
  sb.write_string(ESC)
  sb.write_string("[0")
  if (flags & @term.FLAG_BOLD) != 0 {
    sb.write_string(";1")
  }
  if (flags & @term.FLAG_DIM) != 0 {
    sb.write_string(";2")
  }
  if (flags & @term.FLAG_ITALIC) != 0 {
    sb.write_string(";3")
  }
  if (flags & @term.FLAG_UNDERLINE) != 0 {
    sb.write_string(";4")
  }
  if (flags & @term.FLAG_BLINK) != 0 {
    sb.write_string(";5")
  }
  if (flags & @term.FLAG_REVERSE) != 0 {
    sb.write_string(";7")
  }
  if (flags & @term.FLAG_HIDDEN) != 0 {
    sb.write_string(";8")
  }
  if (flags & @term.FLAG_STRIKE) != 0 {
    sb.write_string(";9")
  }
  append_color(sb, fg, true)
  append_color(sb, bg, false)
  sb.write_string("m")
  sb.to_string()
}

///|
/// Append a colour operand, or nothing at all when the colour is the default.
/// Omitting it lets the reset in the same sequence stand, so a default
/// foreground really does mean "the terminal's own".
fn append_color(sb : StringBuilder, c : Int, is_fg : Bool) -> Unit {
  if c < 0 {
    return
  }
  if @term.color_is_rgb(c) {
    sb.write_string(";")
    sb.write_string(if is_fg { "38" } else { "48" })
    sb.write_string(";2;")
    sb.write_string(@term.color_red(c).to_string())
    sb.write_char(';')
    sb.write_string(@term.color_green(c).to_string())
    sb.write_char(';')
    sb.write_string(@term.color_blue(c).to_string())
  } else {
    sb.write_string(";")
    sb.write_string(if is_fg { "38" } else { "48" })
    sb.write_string(";5;")
    sb.write_string(@term.color_index_of(c).to_string())
  }
}

///|
/// `to_ansi` encoded as UTF-8 bytes, ready to write to a stream.
///
/// Kept separate from `to_ansi` so the string form stays convenient for tests
/// and for embedding, while callers that actually emit bytes do not each have
/// to reach for an encoder.
pub fn to_ansi_bytes(t : @term.Terminal) -> Bytes {
  @utf8.encode(to_ansi(t))
}

///|
/// Index of the last cell in row `y` that carries anything visible, or `-1`
/// when the row is entirely blank.
///
/// A cell counts as content when it holds a character other than a space or
/// carries a background colour; a background colour alone still paints the row,
/// so it must not be trimmed. Skipping the trailing blanks keeps the markup and
/// the ANSI stream proportional to what is actually on screen.
fn last_content_cell(t : @term.Terminal, y : Int) -> Int {
  let (_rows, cols) = t.size()
  let mut last = -1
  let mut x = 0
  while x < cols {
    let (ch, _fg, bg, _flags) = t.cell_at(x, y)
    if ch != ' ' || bg != @term.COLOR_DEFAULT {
      last = x
    }
    x = x + 1
  }
  last
}

///|
/// Re-emit the screen as an ANSI byte stream, one line per row.
///
/// Feeding this back into a terminal reproduces the screen, which is what
/// `render_wbtest.mbt` checks: the engine's own output is fed through the engine
/// again and the two screens must match. That round trip is a strong check on
/// the renderer, because any attribute it drops or mis-orders shows up as a
/// difference on the second pass.
pub fn to_ansi(t : @term.Terminal) -> String {
  let (rows, _cols) = t.size()
  let sb = StringBuilder()
  // Stop at the last row that has anything on it, so a blank screen renders to
  // the empty string and a screen whose lower half is empty does not trail a
  // run of bare line breaks. Blank rows *between* content are still emitted,
  // because they carry vertical position.
  let mut last_row = -1
  let mut probe = 0
  while probe < rows {
    if last_content_cell(t, probe) >= 0 {
      last_row = probe
    }
    probe = probe + 1
  }
  let mut y = 0
  while y <= last_row {
    if y > 0 {
      sb.write_string("\r\n")
    }
    let last = last_content_cell(t, y)
    // Track the pen actually written to the output, which is not the same as
    // the cell's pen: consecutive cells usually share one, and re-emitting SGR
    // per cell would triple the size of the stream.
    let mut cur_fg = @term.COLOR_DEFAULT
    let mut cur_bg = @term.COLOR_DEFAULT
    let mut cur_flags = 0
    let mut pen_set = false
    let mut x = 0
    while x <= last {
      let (ch, fg, bg, flags) = t.cell_at(x, y)
      if @term.is_wide_tail(flags) {
        // The trailing half of a wide character has no text of its own; the
        // lead cell already emitted the character.
        x = x + 1
        continue
      }
      if !pen_set || fg != cur_fg || bg != cur_bg || flags != cur_flags {
        sb.write_string(sgr_for(fg, bg, flags))
        cur_fg = fg
        cur_bg = bg
        cur_flags = flags
        pen_set = true
      }
      sb.write_char(ch)
      x = x + 1
    }
    if pen_set {
      sb.write_string(ESC)
      sb.write_string("[0m")
    }
    y = y + 1
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// HTML
// ---------------------------------------------------------------------------

///|
/// Escape the characters that would otherwise be read as markup.
pub fn escape_html(s : String) -> String {
  let sb = StringBuilder()
  for ch in s {
    if ch == '<' {
      sb.write_string("&lt;")
    } else if ch == '>' {
      sb.write_string("&gt;")
    } else if ch == '&' {
      sb.write_string("&amp;")
    } else if ch == '"' {
      sb.write_string("&quot;")
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
/// The CSS declarations for one cell's pen, or the empty string when the cell
/// is drawn with the default pen and needs no styling at all.
///
/// `fg_default` and `bg_default` are the colours the surrounding page already
/// uses, so a default cell inherits them and contributes no markup.
fn cell_style(
  fg : Int,
  bg : Int,
  flags : Int,
  fg_default : String,
  bg_default : String,
) -> String {
  let sb = StringBuilder()
  if fg >= 0 {
    sb.write_string("color:")
    sb.write_string(css_color(fg, fg_default))
    sb.write_char(';')
  }
  if bg >= 0 {
    sb.write_string("background:")
    sb.write_string(css_color(bg, bg_default))
    sb.write_char(';')
  }
  if (flags & @term.FLAG_BOLD) != 0 {
    sb.write_string("font-weight:bold;")
  }
  if (flags & @term.FLAG_DIM) != 0 {
    sb.write_string("opacity:.6;")
  }
  if (flags & @term.FLAG_ITALIC) != 0 {
    sb.write_string("font-style:italic;")
  }
  if (flags & @term.FLAG_UNDERLINE) != 0 {
    sb.write_string("text-decoration:underline;")
  }
  if (flags & @term.FLAG_STRIKE) != 0 {
    sb.write_string("text-decoration:line-through;")
  }
  if (flags & @term.FLAG_HIDDEN) != 0 {
    sb.write_string("visibility:hidden;")
  }
  sb.to_string()
}

///|
/// Render the screen as HTML: one `<div>` per row, containing one `<span>` per
/// run of cells that share a pen.
///
/// Runs are merged rather than emitting a span per cell, which keeps the markup
/// for a typical screen roughly an order of magnitude smaller and makes the
/// output readable when a test fails.
pub fn to_html(
  t : @term.Terminal,
  fg_default : String,
  bg_default : String,
) -> String {
  let (rows, _cols) = t.size()
  let sb = StringBuilder()
  let mut y = 0
  while y < rows {
    sb.write_string("<div class=\"row\">")
    let last = last_content_cell(t, y)
    let mut x = 0
    while x <= last {
      let (_ch, fg, bg, flags) = t.cell_at(x, y)
      if @term.is_wide_tail(flags) {
        x = x + 1
        continue
      }
      let style = cell_style(fg, bg, flags, fg_default, bg_default)
      // Emit the run of following cells that share this pen, then close the
      // span once.
      let text = StringBuilder()
      let run_fg = fg
      let run_bg = bg
      let run_flags = flags
      let mut cx = x
      while cx <= last {
        let (cch, cfg, cbg, cflags) = t.cell_at(cx, y)
        if cfg != run_fg || cbg != run_bg || cflags != run_flags {
          break
        }
        if !@term.is_wide_tail(cflags) {
          text.write_char(cch)
        }
        cx = cx + 1
      }
      if style.length() > 0 {
        sb.write_string("<span style=\"")
        sb.write_string(style)
        sb.write_string("\">")
      } else {
        sb.write_string("<span>")
      }
      sb.write_string(escape_html(text.to_string()))
      sb.write_string("</span>")
      x = cx
    }
    sb.write_string("</div>")
    y = y + 1
  }
  sb.to_string()
}
