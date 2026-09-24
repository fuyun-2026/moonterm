///|
/// One character cell: the text plus the attributes it was drawn with.
pub struct Cell {
  mut ch : Char
  mut fg : Int
  mut bg : Int
  mut flags : Int
}

///|
pub fn Cell::new() -> Cell {
  { ch: ' ', fg: COLOR_DEFAULT, bg: COLOR_DEFAULT, flags: 0, }
}

///|
/// Erase the character but keep the attributes, which is what selective erase
/// (`CSI K`, `CSI J`) does: the pen's background still paints the row.
pub fn Cell::erase(self : Cell) -> Unit {
  self.ch = ' '
  // Keep the SGR bits, drop the wide/wide-tail markers: the cell is no longer
  // half of a double-width character.
  self.flags = self.flags & FLAG_SGR_MASK
}

///|
/// Overwrite every field, used when the pen writes a fresh cell.
pub fn Cell::set(
  self : Cell,
  ch : Char,
  fg : Int,
  bg : Int,
  flags : Int,
) -> Unit {
  self.ch = ch
  self.fg = fg
  self.bg = bg
  self.flags = flags
}

///|
pub fn Cell::copy_from(self : Cell, other : Cell) -> Unit {
  self.ch = other.ch
  self.fg = other.fg
  self.bg = other.bg
  self.flags = other.flags
}

///|
pub fn Cell::is_blank(self : Cell) -> Bool {
  self.ch == ' ' && self.flags == 0
}

///|
/// A rectangular grid of cells. Rows are `Array[Cell]` and each `Cell` is its
/// own object, so writing to one never disturbs another.
pub struct Grid {
  mut rows : Array[Array[Cell]]
  mut cols : Int
  mut height : Int
}

///|
pub fn Grid::new(height : Int, cols : Int) -> Grid {
  // `Array::make` would repeat one Cell object across every slot; makei builds
  // a distinct cell per position.
  let rows = Array::makei(height, fn(_y) {
    Array::makei(cols, fn(_x) { Cell::new() })
  })
  { rows, cols, height, }
}

///|
/// The cell at (x, y). Callers may mutate it directly.
pub fn Grid::cell(self : Grid, x : Int, y : Int) -> Cell {
  self.rows[y][x]
}

///|
pub fn Grid::row(self : Grid, y : Int) -> Array[Cell] {
  self.rows[y]
}

///|
/// Fill a row with blanks carrying `bg`, leaving the characters erased.
pub fn Grid::clear_row(self : Grid, y : Int, bg : Int) -> Unit {
  let row = self.rows[y]
  for i in 0..<self.cols {
    row[i].ch = ' '
    row[i].flags = 0
    row[i].fg = COLOR_DEFAULT
    row[i].bg = bg
  }
}

///|
/// Fill a cell range of one row with blanks carrying `bg`.
pub fn Grid::clear_range(
  self : Grid,
  y : Int,
  from : Int,
  to : Int,
  bg : Int,
) -> Unit {
  let row = self.rows[y]
  let start = if from < 0 { 0 } else { from }
  let stop = if to > self.cols { self.cols } else { to }
  let mut x = start
  while x < stop {
    row[x].ch = ' '
    row[x].flags = 0
    row[x].fg = COLOR_DEFAULT
    row[x].bg = bg
    x = x + 1
  }
}

///|
/// Scroll the inclusive row range `[top, bottom]` up by `count` lines. Rows
/// pushed off the top are lost; new blank rows enter from the bottom.
pub fn Grid::scroll_up(
  self : Grid,
  top : Int,
  bottom : Int,
  count : Int,
  bg : Int,
) -> Unit {
  if count <= 0 || top > bottom {
    return
  }
  let span = bottom - top + 1
  let n = if count > span { span } else { count }
  // Rotate the row references rather than copying cells: each row is an
  // array of stable Cell objects, so moving the array moves everything.
  let mut i = 0
  while i < n {
    let moved = self.rows[top]
    let mut j = top
    while j < bottom {
      self.rows[j] = self.rows[j + 1]
      j = j + 1
    }
    self.rows[bottom] = moved
    self.clear_row(bottom, bg)
    i = i + 1
  }
}

///|
/// Scroll the inclusive row range `[top, bottom]` down by `count` lines.
pub fn Grid::scroll_down(
  self : Grid,
  top : Int,
  bottom : Int,
  count : Int,
  bg : Int,
) -> Unit {
  if count <= 0 || top > bottom {
    return
  }
  let span = bottom - top + 1
  let n = if count > span { span } else { count }
  let mut i = 0
  while i < n {
    let moved = self.rows[bottom]
    let mut j = bottom
    while j > top {
      self.rows[j] = self.rows[j - 1]
      j = j - 1
    }
    self.rows[top] = moved
    self.clear_row(top, bg)
    i = i + 1
  }
}

///|
/// Insert `count` blank lines at `y`, pushing later rows in the scroll region
/// down and discarding those past `bottom`.
pub fn Grid::insert_lines(
  self : Grid,
  y : Int,
  bottom : Int,
  count : Int,
  bg : Int,
) -> Unit {
  if y > bottom {
    return
  }
  self.scroll_down(y, bottom, count, bg)
}

///|
/// Delete `count` lines starting at `y`, pulling later rows up.
pub fn Grid::delete_lines(
  self : Grid,
  y : Int,
  bottom : Int,
  count : Int,
  bg : Int,
) -> Unit {
  if y > bottom {
    return
  }
  self.scroll_up(y, bottom, count, bg)
}

///|
/// Resize in place, keeping the top-left corner of the existing content.
pub fn Grid::resize(self : Grid, height : Int, cols : Int) -> Unit {
  let new_rows = Array::makei(height, fn(y) {
    if y < self.height {
      let old = self.rows[y]
      // Existing cells are reused so their contents survive the resize; only
      // positions past the old width need fresh cells.
      Array::makei(cols, fn(x) {
        if x < self.cols {
          old[x]
        } else {
          Cell::new()
        }
      })
    } else {
      Array::makei(cols, fn(_x) { Cell::new() })
    }
  })
  self.rows = new_rows
  self.cols = cols
  self.height = height
}

///|
/// Render a row of cells as text.
///
/// When `trim` is set, trailing blanks are dropped, which is what a plain-text
/// screen dump for humans wants. When it is clear the result is exactly `cols`
/// characters — minus one for each double-width character, whose trailing half
/// contributes nothing — which is the fixed-width form the differential tests
/// compare against the reference emulator.
///
/// A wide character contributes its lead cell only, in both modes, so the
/// result reads naturally.
pub fn cells_to_text(row : Array[Cell], cols : Int, trim : Bool) -> String {
  let mut last = cols - 1
  if trim {
    last = -1
    let mut x = 0
    while x < cols {
      let c = row[x]
      // A cell counts as content if it holds a character or carries a
      // background colour; a coloured trailing cell still paints the row.
      if c.ch != ' ' || c.bg != COLOR_DEFAULT {
        last = x
      }
      x = x + 1
    }
  }
  let sb = StringBuilder()
  let mut i = 0
  while i <= last {
    let c = row[i]
    if !is_wide_tail(c.flags) {
      sb.write_char(c.ch)
    }
    i = i + 1
  }
  sb.to_string()
}

///|
/// Render one row as text with trailing blanks trimmed.
pub fn Grid::row_text(self : Grid, y : Int) -> String {
  cells_to_text(self.rows[y], self.cols, true)
}

///|
/// Render one row at full width, for differential comparison with a reference
/// emulator.
pub fn Grid::row_dump(self : Grid, y : Int) -> String {
  cells_to_text(self.rows[y], self.cols, false)
}
