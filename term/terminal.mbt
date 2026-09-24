///|
/// Cursor position and pen state captured by `ESC 7` / `CSI s`, restored by
/// `ESC 8` / `CSI u`.
pub struct Saved {
  x : Int
  y : Int
  fg : Int
  bg : Int
  flags : Int
}

///|
/// How many lines of history a terminal keeps by default.
pub const DEFAULT_SCROLLBACK : Int = 1000

///|
/// Bounded history of the lines that have scrolled off the top of the primary
/// screen, held as a ring of row arrays.
///
/// Rows are *copied* on entry rather than referenced, because `Grid::scroll_up`
/// recycles row arrays: keeping a reference would let the next scroll overwrite
/// history in place.
pub struct Scrollback {
  rows : Array[Array[Cell]]
  /// Index of the oldest retained row.
  mut head : Int
  /// Number of rows currently retained.
  mut len : Int
}

///|
pub fn Scrollback::new(capacity : Int) -> Scrollback {
  let cap = if capacity < 1 { 1 } else { capacity }
  { rows: Array::make(cap, []), head: 0, len: 0, }
}

///|
pub fn Scrollback::capacity(self : Scrollback) -> Int {
  self.rows.length()
}

///|
pub fn Scrollback::length(self : Scrollback) -> Int {
  self.len
}

///|
/// Append one row, copying its cells. When the ring is full the oldest row is
/// overwritten, so memory stays bounded no matter how long the stream runs.
pub fn Scrollback::push(self : Scrollback, row : Array[Cell]) -> Unit {
  let cap = self.capacity()
  // With the ring full, `head` is exactly the slot to overwrite.
  let slot = (self.head + self.len) % cap
  let width = row.length()
  let existing = self.rows[slot]
  // Reuse the stored array when the width is unchanged; discard it when the
  // terminal has been resized, since the old row is the wrong shape.
  let target = if existing.length() == width {
    existing
  } else {
    Array::makei(width, fn(_x) { Cell::new() })
  }
  let mut x = 0
  while x < width {
    target[x].copy_from(row[x])
    x = x + 1
  }
  self.rows[slot] = target
  if self.len < cap {
    self.len = self.len + 1
  } else {
    self.head = (self.head + 1) % cap
  }
}

///|
/// The `i`-th retained row, counting from the oldest. The caller must ensure
/// `0 <= i < length()`.
pub fn Scrollback::row(self : Scrollback, i : Int) -> Array[Cell] {
  self.rows[(self.head + i) % self.capacity()]
}

///|
pub fn Scrollback::clear(self : Scrollback) -> Unit {
  self.head = 0
  self.len = 0
}

///|
/// A terminal screen: the parser feeds it bytes, it maintains a cell grid,
/// a cursor and a pen.
///
/// The screen is a pure data structure. Nothing here touches an operating
/// system terminal, which is what makes the whole thing testable by comparing
/// rendered rows against expected text.
pub struct Terminal {
  cols : Int
  rows : Int
  main : Grid
  alt : Grid
  mut on_alt : Bool
  mut x : Int
  mut y : Int
  mut pen_fg : Int
  mut pen_bg : Int
  mut pen_flags : Int
  mut scroll_top : Int
  mut scroll_bottom : Int
  /// Set when the cursor rests on the last column after printing: the next
  /// printable character wraps first, so that filling the last cell does not
  /// scroll the screen until one more character actually arrives.
  mut wrap_pending : Bool
  mut autowrap : Bool
  mut origin_mode : Bool
  mut cursor_visible : Bool
  mut saved : Saved
  mut has_saved : Bool
  mut title : String
  scrollback : Scrollback
  parser : @vt.Parser
}

///|
pub fn Terminal::new(rows : Int, cols : Int) -> Terminal {
  Terminal::with_scrollback(rows, cols, DEFAULT_SCROLLBACK)
}

///|
/// Build a terminal with an explicit history size. `capacity` of zero disables
/// history, which is what the differential tests use: they compare the visible
/// screen only, and a smaller ring keeps those tests allocation-light.
pub fn Terminal::with_scrollback(
  rows : Int,
  cols : Int,
  capacity : Int,
) -> Terminal {
  {
    cols,
    rows,
    main: Grid::new(rows, cols),
    alt: Grid::new(rows, cols),
    on_alt: false,
    x: 0,
    y: 0,
    pen_fg: COLOR_DEFAULT,
    pen_bg: COLOR_DEFAULT,
    pen_flags: 0,
    scroll_top: 0,
    scroll_bottom: rows - 1,
    wrap_pending: false,
    autowrap: true,
    origin_mode: false,
    cursor_visible: true,
    saved: { x: 0, y: 0, fg: COLOR_DEFAULT, bg: COLOR_DEFAULT, flags: 0, },
    has_saved: false,
    title: "",
    scrollback: Scrollback::new(capacity),
    parser: @vt.Parser::new(),
  }
}

///|
/// Feed bytes into the terminal. Chunks may be split anywhere.
pub fn Terminal::feed(self : Terminal, bytes : Bytes) -> Unit {
  self.parser.feed(self, bytes)
}

///|
/// Signal end of input, flushing any half-decoded character.
pub fn Terminal::finish(self : Terminal) -> Unit {
  self.parser.finish(self)
}

///|
/// The grid currently on screen.
fn Terminal::grid(self : Terminal) -> Grid {
  if self.on_alt {
    self.alt
  } else {
    self.main
  }
}

///|
pub fn Terminal::cursor(self : Terminal) -> (Int, Int) {
  (self.x, self.y)
}

///|
/// Screen size as `(rows, cols)`.
pub fn Terminal::size(self : Terminal) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
/// The cell at `(x, y)` on the visible screen, as
/// `(character, foreground, background, flags)`.
///
/// Colours are the packed values documented in `attr.mbt`; `flags` is the SGR
/// and wide-character bitfield. Renderers need both without the terminal having
/// to know which output format it is being rendered into.
pub fn Terminal::cell_at(
  self : Terminal,
  x : Int,
  y : Int,
) -> (Char, Int, Int, Int) {
  let c = self.grid().cell(x, y)
  (c.ch, c.fg, c.bg, c.flags)
}

///|
pub fn Terminal::title_text(self : Terminal) -> String {
  self.title
}

///|
pub fn Terminal::is_on_alt(self : Terminal) -> Bool {
  self.on_alt
}

///|
pub fn Terminal::cursor_is_visible(self : Terminal) -> Bool {
  self.cursor_visible
}

///|
/// Render one row as text with trailing blanks trimmed.
pub fn Terminal::row_text(self : Terminal, y : Int) -> String {
  self.grid().row_text(y)
}

///|
/// Render one row at full width. This is the form the differential tests
/// compare against the reference emulator: every grid column contributes
/// exactly one character, so a mismatch in trailing-blank handling or wide
/// character placement shows up rather than being trimmed away.
pub fn Terminal::row_dump(self : Terminal, y : Int) -> String {
  self.grid().row_dump(y)
}

///|
/// The whole visible screen at full width, one row per line, with no trailing
/// newline. The differential tests compare this single string, so a failure
/// shows the entire grid instead of stopping at the first differing row.
pub fn Terminal::screen_dump(self : Terminal) -> String {
  let sb = StringBuilder()
  let mut y = 0
  while y < self.rows {
    if y > 0 {
      sb.write_char('\n')
    }
    sb.write_string(self.row_dump(y))
    y = y + 1
  }
  sb.to_string()
}

// ---------------------------------------------------------------- scrollback

///|
/// Number of lines currently held in history.
pub fn Terminal::scrollback_len(self : Terminal) -> Int {
  self.scrollback.length()
}

///|
/// One line of history, counting from the oldest retained line. Everything the
/// terminal has ever scrolled off is available this way, up to the ring
/// capacity.
pub fn Terminal::scrollback_text(self : Terminal, i : Int) -> String {
  cells_to_text(self.scrollback.row(i), self.cols, true)
}

///|
/// The whole history as one string, oldest line first.
pub fn Terminal::scrollback_dump(self : Terminal) -> String {
  let sb = StringBuilder()
  let n = self.scrollback.length()
  let mut i = 0
  while i < n {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(self.scrollback_text(i))
    i = i + 1
  }
  sb.to_string()
}

///|
/// History followed by the visible screen, i.e. everything a user could reach
/// by scrolling up.
pub fn Terminal::full_text(self : Terminal) -> String {
  let sb = StringBuilder()
  let history = self.scrollback_dump()
  if history.length() > 0 {
    sb.write_string(history)
    sb.write_char('\n')
  }
  sb.write_string(self.screen_text())
  sb.to_string()
}

///|
/// Render the whole visible screen, one line per row.
pub fn Terminal::screen_text(self : Terminal) -> String {
  let sb = StringBuilder()
  let mut y = 0
  while y < self.rows {
    sb.write_string(self.row_text(y))
    if y < self.rows - 1 {
      sb.write_char('\n')
    }
    y = y + 1
  }
  sb.to_string()
}

// ---------------------------------------------------------------- cursor moves

///|
fn Terminal::line_feed(self : Terminal) -> Unit {
  // Any cursor motion resolves a pending wrap. The flag means "the next
  // printable character must wrap first"; once the cursor has been moved by a
  // control character there is no wrap left to perform, and leaving the flag
  // set makes the *following* character consume an extra line.
  self.wrap_pending = false
  if self.y == self.scroll_bottom {
    // Only the primary screen keeps history. The alternate screen is a scratch
    // buffer that full-screen programs expect to be discarded, and a scroll
    // region that does not start at the top of the screen scrolls *within* the
    // screen rather than pushing lines off it.
    if !self.on_alt && self.scroll_top == 0 {
      self.scrollback.push(self.main.row(self.scroll_top))
    }
    self.grid().scroll_up(self.scroll_top, self.scroll_bottom, 1, self.pen_bg)
  } else if self.y < self.rows - 1 {
    self.y = self.y + 1
  }
}

///|
fn Terminal::reverse_index(self : Terminal) -> Unit {
  if self.y == self.scroll_top {
    self.grid().scroll_down(self.scroll_top, self.scroll_bottom, 1, self.pen_bg)
  } else if self.y > 0 {
    self.y = self.y - 1
  }
}

///|
fn Terminal::carriage_return(self : Terminal) -> Unit {
  self.x = 0
  self.wrap_pending = false
}

///|
fn Terminal::backspace(self : Terminal) -> Unit {
  if self.x > 0 {
    self.x = self.x - 1
  }
  self.wrap_pending = false
}

///|
/// Advance to the next multiple of eight, as hardware terminals do.
fn Terminal::tab(self : Terminal) -> Unit {
  let next = (self.x / 8 + 1) * 8
  self.x = if next < self.cols { next } else { self.cols - 1 }
  self.wrap_pending = false
}

///|
fn Terminal::clamp_x(self : Terminal, v : Int) -> Int {
  if v < 0 {
    0
  } else if v > self.cols - 1 {
    self.cols - 1
  } else {
    v
  }
}

///|
fn Terminal::clamp_y(self : Terminal, v : Int) -> Int {
  if v < 0 {
    self.scroll_top
  } else if v > self.scroll_bottom {
    self.scroll_bottom
  } else {
    v
  }
}

///|
/// Clamp an *absolute* row request — `CSI H`/`CSI f` and `CSI d`.
///
/// This is deliberately not `clamp_y`. Cursor *movement* (`CUU`/`CUD`) is
/// bounded by the scroll region whichever mode is in force, but absolute
/// positioning is only region-relative when origin mode is on. With origin mode
/// off, `CSI <row> H` addresses the whole screen and a row below the region must
/// land below the region rather than being pulled up to its bottom edge.
fn Terminal::clamp_absolute_row(self : Terminal, v : Int) -> Int {
  let lo = if self.origin_mode { self.scroll_top } else { 0 }
  let hi = if self.origin_mode { self.scroll_bottom } else { self.rows - 1 }
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// Absolute cursor positioning. Row and column are 1-based in the protocol.
fn Terminal::goto(self : Terminal, row1 : Int, col1 : Int) -> Unit {
  let base = if self.origin_mode { self.scroll_top } else { 0 }
  // A zero row/column means "the first one", so it is normalised to 1-based
  // before being converted back to a zero-based index.
  let row = if row1 > 0 { row1 - 1 } else { 0 }
  let col = if col1 > 0 { col1 - 1 } else { 0 }
  self.y = self.clamp_absolute_row(base + row)
  self.x = self.clamp_x(col)
  self.wrap_pending = false
}

// ---------------------------------------------------------------- printing

///|
/// Write one character at the cursor, honouring automatic wrapping and
/// double-width characters.
pub fn Terminal::put_char(self : Terminal, ch : Char) -> Unit {
  let w = char_width(ch)
  if w == 0 {
    // Combining marks and zero-width formatting characters are dropped for
    // now; see the limitations section of the README.
    return
  }
  if self.wrap_pending {
    self.wrap_pending = false
    self.x = 0
    self.line_feed()
  }
  let g = self.grid()
  if w == 2 {
    if self.x >= self.cols - 1 {
      if self.autowrap {
        self.x = 0
        self.line_feed()
      } else {
        // Without autowrap a wide character cannot straddle the margin, so
        // it is placed as far right as it fits.
        self.x = self.cols - 2
      }
    }
    g
    .cell(self.x, self.y)
    .set(ch, self.pen_fg, self.pen_bg, self.pen_flags | FLAG_WIDE)
    g
    .cell(self.x + 1, self.y)
    .set(' ', self.pen_fg, self.pen_bg, self.pen_flags | FLAG_WIDE_TAIL)
    self.x = self.x + 2
    if self.x >= self.cols {
      self.x = self.cols - 1
      self.wrap_pending = true
    }
    return
  }
  g.cell(self.x, self.y).set(ch, self.pen_fg, self.pen_bg, self.pen_flags)
  if self.x == self.cols - 1 {
    if self.autowrap {
      self.wrap_pending = true
    }
  } else {
    self.x = self.x + 1
  }
}

// ---------------------------------------------------------------- erase

///|
fn Terminal::erase_line(self : Terminal, mode : Int) -> Unit {
  let bg = self.pen_bg
  let g = self.grid()
  if mode == 0 {
    g.clear_range(self.y, self.x, self.cols, bg)
  } else if mode == 1 {
    g.clear_range(self.y, 0, self.x + 1, bg)
  } else if mode == 2 {
    g.clear_range(self.y, 0, self.cols, bg)
  }
}

///|
fn Terminal::erase_display(self : Terminal, mode : Int) -> Unit {
  let bg = self.pen_bg
  let g = self.grid()
  if mode == 0 {
    g.clear_range(self.y, self.x, self.cols, bg)
    let mut y = self.y + 1
    while y < self.rows {
      g.clear_row(y, bg)
      y = y + 1
    }
  } else if mode == 1 {
    let mut y = 0
    while y < self.y {
      g.clear_row(y, bg)
      y = y + 1
    }
    g.clear_range(self.y, 0, self.x + 1, bg)
  } else if mode == 2 || mode == 3 {
    let mut y = 0
    while y < self.rows {
      g.clear_row(y, bg)
      y = y + 1
    }
  }
}

///|
/// Erase `n` characters in place without moving anything else (`CSI X`).
fn Terminal::erase_chars(self : Terminal, n : Int) -> Unit {
  self.grid().clear_range(self.y, self.x, self.x + n, self.pen_bg)
}

///|
/// `CSI P` — remove `n` characters, pulling the rest of the row left.
fn Terminal::delete_chars(self : Terminal, n : Int) -> Unit {
  if n <= 0 {
    return
  }
  let g = self.grid()
  let row = g.row(self.y)
  let mut x = self.x
  while x < self.cols {
    let src = x + n
    if src < self.cols {
      row[x].copy_from(row[src])
    } else {
      row[x].ch = ' '
      row[x].flags = 0
      row[x].fg = COLOR_DEFAULT
      row[x].bg = self.pen_bg
    }
    x = x + 1
  }
}

///|
/// `CSI @` — open a gap of `n` blanks, pushing the rest of the row right.
fn Terminal::insert_chars(self : Terminal, n : Int) -> Unit {
  if n <= 0 {
    return
  }
  let g = self.grid()
  let row = g.row(self.y)
  let mut x = self.cols - 1
  while x >= self.x {
    let src = x - n
    if src >= self.x {
      row[x].copy_from(row[src])
    } else {
      row[x].ch = ' '
      row[x].flags = 0
      row[x].fg = COLOR_DEFAULT
      row[x].bg = self.pen_bg
    }
    x = x - 1
  }
}

// ---------------------------------------------------------------- modes

///|
fn Terminal::set_scroll_region(
  self : Terminal,
  top1 : Int,
  bottom1 : Int,
) -> Unit {
  let top = if top1 > 0 { top1 - 1 } else { 0 }
  let bottom = if bottom1 > 0 { bottom1 - 1 } else { self.rows - 1 }
  if top < bottom && bottom < self.rows {
    self.scroll_top = top
    self.scroll_bottom = bottom
  } else {
    self.scroll_top = 0
    self.scroll_bottom = self.rows - 1
  }
  self.x = 0
  self.y = self.scroll_top
  self.wrap_pending = false
}

///|
fn Terminal::save_cursor(self : Terminal) -> Unit {
  self.saved = {
    x: self.x,
    y: self.y,
    fg: self.pen_fg,
    bg: self.pen_bg,
    flags: self.pen_flags,
  }
  self.has_saved = true
}

///|
fn Terminal::restore_cursor(self : Terminal) -> Unit {
  if !self.has_saved {
    return
  }
  self.x = self.clamp_x(self.saved.x)
  self.y = self.clamp_y(self.saved.y)
  self.pen_fg = self.saved.fg
  self.pen_bg = self.saved.bg
  self.pen_flags = self.saved.flags
  self.wrap_pending = false
}

///|
/// Switch between the primary and alternate screens. `1049` also saves and
/// restores the cursor, which is what full-screen programs such as `vim` and
/// `less` expect.
fn Terminal::use_alt(self : Terminal, on : Bool, with_cursor : Bool) -> Unit {
  if on == self.on_alt {
    return
  }
  // Only save on the way *in*. Saving on the way out would capture the
  // alternate screen's cursor and immediately restore it, so the cursor would
  // never return to where the program left it on the primary screen.
  if on && with_cursor {
    self.save_cursor()
  }
  self.on_alt = on
  if on {
    let g = self.alt
    let mut y = 0
    while y < self.rows {
      g.clear_row(y, COLOR_DEFAULT)
      y = y + 1
    }
    self.x = 0
    self.y = 0
    self.scroll_top = 0
    self.scroll_bottom = self.rows - 1
    self.wrap_pending = false
  } else if with_cursor {
    self.restore_cursor()
  }
}

///|
/// `CSI h` / `CSI l`. With the `?` marker these are DEC private modes; without
/// it they are ANSI modes, none of which we act on yet.
fn Terminal::set_mode(
  self : Terminal,
  marker : Int,
  params : ArrayView[Int],
  on : Bool,
) -> Unit {
  if marker != 0x3F {
    return
  }
  for i in 0..<params.length() {
    let p = params[i]
    if p == 7 {
      self.autowrap = on
      self.wrap_pending = false
    } else if p == 25 {
      self.cursor_visible = on
    } else if p == 6 {
      self.origin_mode = on
      self.goto(1, 1)
    } else if p == 47 || p == 1047 {
      self.use_alt(on, false)
    } else if p == 1049 {
      self.use_alt(on, true)
    } else {
      // 1 (application cursor keys), 12 (cursor blink), 2004 (bracketed
      // paste) and friends are accepted and remembered by real terminals but
      // do not change the visible screen, so they need no state here yet.
    }
  }
}

// ---------------------------------------------------------------- SGR

///|
fn Terminal::attr_reset(self : Terminal) -> Unit {
  self.pen_fg = COLOR_DEFAULT
  self.pen_bg = COLOR_DEFAULT
  self.pen_flags = 0
}

///|
fn Terminal::sgr(self : Terminal, params : ArrayView[Int]) -> Unit {
  let n = params.length()
  if n == 0 {
    self.attr_reset()
    return
  }
  let mut i = 0
  while i < n {
    let p = params[i]
    if p == 0 {
      self.attr_reset()
    } else if p == 1 {
      self.pen_flags = self.pen_flags | FLAG_BOLD
    } else if p == 2 {
      self.pen_flags = self.pen_flags | FLAG_DIM
    } else if p == 3 {
      self.pen_flags = self.pen_flags | FLAG_ITALIC
    } else if p == 4 {
      self.pen_flags = self.pen_flags | FLAG_UNDERLINE
    } else if p == 5 || p == 6 {
      self.pen_flags = self.pen_flags | FLAG_BLINK
    } else if p == 7 {
      self.pen_flags = self.pen_flags | FLAG_REVERSE
    } else if p == 8 {
      self.pen_flags = self.pen_flags | FLAG_HIDDEN
    } else if p == 9 {
      self.pen_flags = self.pen_flags | FLAG_STRIKE
    } else if p == 21 || p == 22 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_BOLD | FLAG_DIM)
    } else if p == 23 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_ITALIC)
    } else if p == 24 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_UNDERLINE)
    } else if p == 25 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_BLINK)
    } else if p == 27 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_REVERSE)
    } else if p == 28 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_HIDDEN)
    } else if p == 29 {
      self.pen_flags = flag_clear(self.pen_flags, FLAG_STRIKE)
    } else if p >= 30 && p <= 37 {
      self.pen_fg = color_indexed(p - 30)
    } else if p == 39 {
      self.pen_fg = COLOR_DEFAULT
    } else if p >= 40 && p <= 47 {
      self.pen_bg = color_indexed(p - 40)
    } else if p == 49 {
      self.pen_bg = COLOR_DEFAULT
    } else if p >= 90 && p <= 97 {
      self.pen_fg = color_indexed(p - 90 + 8)
    } else if p >= 100 && p <= 107 {
      self.pen_bg = color_indexed(p - 100 + 8)
    } else if p == 38 || p == 48 {
      // 38;5;N / 38;2;R;G;B and the 48 equivalents. `i` is advanced past the
      // consumed parameters so the loop does not reinterpret the components
      // as independent attributes.
      let fg = p == 38
      if i + 1 < n {
        let kind = params[i + 1]
        if kind == 5 && i + 2 < n {
          let idx = color_indexed(params[i + 2])
          if fg {
            self.pen_fg = idx
          } else {
            self.pen_bg = idx
          }
          i = i + 2
        } else if kind == 2 && i + 4 < n {
          let c = color_rgb(params[i + 2], params[i + 3], params[i + 4])
          if fg {
            self.pen_fg = c
          } else {
            self.pen_bg = c
          }
          i = i + 4
        }
      }
    }
    i = i + 1
  }
}

// ---------------------------------------------------------------- dispatch

///|
/// Read parameter `i`, substituting `default` when it is absent.
fn param_at(params : ArrayView[Int], i : Int, default : Int) -> Int {
  if i < params.length() {
    params[i]
  } else {
    default
  }
}

///|
/// Read a count parameter where an omitted or zero value means one, as every
/// cursor movement sequence specifies.
fn param_count(params : ArrayView[Int], i : Int) -> Int {
  let v = param_at(params, i, 0)
  if v <= 0 {
    1
  } else {
    v
  }
}

///|
/// Clear `bits` from `flags`.
fn flag_clear(flags : Int, bits : Int) -> Int {
  flags & (FLAG_SGR_MASK ^ bits)
}

///|
fn Terminal::csi(
  self : Terminal,
  marker : Int,
  params : ArrayView[Int],
  inter : ArrayView[Byte],
  f : Int,
) -> Unit {
  // Private modes and SGR are the only sequences we act on that may carry
  // intermediates; anything else with one is left alone.
  if inter.length() > 0 && f != 0x71 {
    return
  }
  if f == 0x41 {
    self.y = self.clamp_y(self.y - param_count(params, 0))
    self.wrap_pending = false
  } else if f == 0x42 {
    self.y = self.clamp_y(self.y + param_count(params, 0))
    self.wrap_pending = false
  } else if f == 0x43 {
    self.x = self.clamp_x(self.x + param_count(params, 0))
    self.wrap_pending = false
  } else if f == 0x44 {
    self.x = self.clamp_x(self.x - param_count(params, 0))
    self.wrap_pending = false
  } else if f == 0x45 {
    self.y = self.clamp_y(self.y + param_count(params, 0))
    self.x = 0
    self.wrap_pending = false
  } else if f == 0x46 {
    self.y = self.clamp_y(self.y - param_count(params, 0))
    self.x = 0
    self.wrap_pending = false
  } else if f == 0x47 {
    self.x = self.clamp_x(
      if param_at(params, 0, 0) > 0 {
        param_at(params, 0, 0) - 1
      } else {
        0
      },
    )
    self.wrap_pending = false
  } else if f == 0x48 || f == 0x66 {
    self.goto(param_at(params, 0, 1), param_at(params, 1, 1))
  } else if f == 0x4A {
    self.erase_display(param_at(params, 0, 0))
  } else if f == 0x4B {
    self.erase_line(param_at(params, 0, 0))
  } else if f == 0x4C {
    self
    .grid()
    .insert_lines(
      self.y,
      self.scroll_bottom,
      param_count(params, 0),
      self.pen_bg,
    )
  } else if f == 0x4D {
    self
    .grid()
    .delete_lines(
      self.y,
      self.scroll_bottom,
      param_count(params, 0),
      self.pen_bg,
    )
  } else if f == 0x50 {
    self.delete_chars(param_count(params, 0))
  } else if f == 0x40 {
    self.insert_chars(param_count(params, 0))
  } else if f == 0x58 {
    self.erase_chars(param_count(params, 0))
  } else if f == 0x53 {
    self
    .grid()
    .scroll_up(
      self.scroll_top,
      self.scroll_bottom,
      param_count(params, 0),
      self.pen_bg,
    )
  } else if f == 0x54 {
    self
    .grid()
    .scroll_down(
      self.scroll_top,
      self.scroll_bottom,
      param_count(params, 0),
      self.pen_bg,
    )
  } else if f == 0x64 {
    let base = if self.origin_mode { self.scroll_top } else { 0 }
    self.y = self.clamp_absolute_row(
      base +
      (if param_at(params, 0, 0) > 0 { param_at(params, 0, 0) - 1 } else { 0 }),
    )
    self.wrap_pending = false
  } else if f == 0x72 {
    self.set_scroll_region(param_at(params, 0, 0), param_at(params, 1, 0))
  } else if f == 0x6D {
    self.sgr(params)
  } else if f == 0x68 {
    self.set_mode(marker, params, true)
  } else if f == 0x6C {
    self.set_mode(marker, params, false)
  } else if f == 0x73 {
    self.save_cursor()
  } else if f == 0x75 {
    self.restore_cursor()
  }
  // Anything else is a sequence we do not implement; ignoring it is correct
  // behaviour and keeps unknown extensions from corrupting the screen.
}

///|
/// Split an OSC payload on `;` and return the pieces as strings.
fn split_osc(data : ArrayView[Byte]) -> Array[String] {
  let parts : Array[String] = []
  let sb = StringBuilder()
  for b in data {
    if (b.to_int() & 0xFF) == 0x3B {
      parts.push(sb.to_string())
      sb.reset()
    } else {
      sb.write_char((b.to_int() & 0xFF).unsafe_to_char())
    }
  }
  parts.push(sb.to_string())
  parts
}

// ---------------------------------------------------------------- Handler

///|
impl @vt.Handler for Terminal with fn print(self, ch) {
  self.put_char(ch)
}

///|
impl @vt.Handler for Terminal with fn execute(self, b) {
  let c = b.to_int() & 0xFF
  if c == 0x08 {
    self.backspace()
  } else if c == 0x09 {
    self.tab()
  } else if c == 0x0A || c == 0x0B || c == 0x0C {
    // LF, VT and FF all move down one line in a terminal.
    self.line_feed()
  } else if c == 0x0D {
    self.carriage_return()
  }
  // BEL (0x07) has no audible effect here, and SO/SI (0x0E/0x0F) select
  // character sets we do not implement.
}

///|
impl @vt.Handler for Terminal with fn csi_dispatch(
  self,
  marker,
  params,
  inter,
  f,
) {
  self.csi(marker.to_int() & 0xFF, params, inter, f.to_int() & 0xFF)
}

///|
impl @vt.Handler for Terminal with fn esc_dispatch(self, inter, f) {
  let c = f.to_int() & 0xFF
  if inter.length() > 0 {
    // Character set selection (`ESC ( B`) and DECALN (`ESC # 8`) are accepted
    // and ignored; both only matter for hardware line-drawing characters.
    return
  }
  if c == 0x37 {
    self.save_cursor()
  } else if c == 0x38 {
    self.restore_cursor()
  } else if c == 0x44 {
    self.line_feed()
  } else if c == 0x45 {
    self.carriage_return()
    self.line_feed()
  } else if c == 0x4D {
    self.reverse_index()
  } else if c == 0x63 {
    self.reset()
  }
}

///|
impl @vt.Handler for Terminal with fn osc_dispatch(self, data) {
  let parts = split_osc(data)
  if parts.length() == 0 {
    return
  }
  let cmd = parts[0]
  // OSC 0 sets both icon name and title, OSC 2 sets the title; both land in
  // the same field because a headless screen has no window to title.
  if (cmd == "0" || cmd == "2") && parts.length() > 1 {
    let sb = StringBuilder()
    let mut i = 1
    while i < parts.length() {
      if i > 1 {
        sb.write_char(';')
      }
      sb.write_string(parts[i])
      i = i + 1
    }
    self.title = sb.to_string()
  }
}

///|
/// `ESC c` — reset the terminal to its power-on state.
pub fn Terminal::reset(self : Terminal) -> Unit {
  // Leave the alternate screen *before* clearing, otherwise `grid()` still
  // resolves to the alternate grid and the primary screen is left dirty.
  self.on_alt = false
  let g = self.main
  let mut y = 0
  while y < self.rows {
    g.clear_row(y, COLOR_DEFAULT)
    y = y + 1
  }
  let a = self.alt
  let mut ay = 0
  while ay < self.rows {
    a.clear_row(ay, COLOR_DEFAULT)
    ay = ay + 1
  }
  self.x = 0
  self.y = 0
  self.scroll_top = 0
  self.scroll_bottom = self.rows - 1
  self.attr_reset()
  self.autowrap = true
  self.origin_mode = false
  self.cursor_visible = true
  self.wrap_pending = false
  self.has_saved = false
  self.title = ""
  // A hard reset is a power-on state; history from the previous session is not
  // part of it.
  self.scrollback.clear()
}
