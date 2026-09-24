///|
/// Run bytes through a fresh terminal and return it.
fn run(bytes : Bytes, rows : Int, cols : Int) -> Terminal {
  let t = Terminal::new(rows, cols)
  t.feed(bytes)
  t.finish()
  t
}

///|
/// Run bytes and render the whole screen.
fn screen(bytes : Bytes, rows : Int, cols : Int) -> String {
  run(bytes, rows, cols).screen_text()
}

///|
/// Run bytes and read one cell.
fn cell_at(bytes : Bytes, rows : Int, cols : Int, x : Int, y : Int) -> Cell {
  run(bytes, rows, cols).grid().cell(x, y)
}

///|
test "plain text lands on the first row" {
  inspect(screen(b"abc", 2, 5), content="abc\n")
}

///|
test "carriage return and line feed move independently" {
  inspect(screen(b"a\r\nb", 3, 5), content="a\nb\n")
}

///|
test "a bare line feed keeps the column" {
  inspect(screen(b"ab\nc", 3, 5), content="ab\n  c\n")
}

///|
test "printing past the last column wraps" {
  inspect(screen(b"abcd", 2, 2), content="ab\ncd")
}

///|
test "filling exactly the last cell does not scroll yet" {
  // The cursor rests on the margin; only one more character may wrap.
  inspect(screen(b"ab", 2, 2), content="ab\n")
}

///|
test "the character after a full row wraps to the next line" {
  inspect(screen(b"abc", 2, 2), content="ab\nc")
}

///|
test "autowrap can be turned off" {
  inspect(
    screen(b"\x1b[?7labcde", 2, 3),
    content=(
      #|abe
      #|
    ),
  )
}

///|
test "a wide character occupies two cells" {
  let t = run(b"中", 2, 4)
  inspect(t.grid().cell(0, 0).ch == '中', content="true")
  inspect(is_wide_lead(t.grid().cell(0, 0).flags), content="true")
  inspect(is_wide_tail(t.grid().cell(1, 0).flags), content="true")
  // The trailing half contributes no text of its own.
  inspect(t.row_text(0), content="中")
}

///|
test "a wide character that cannot fit wraps first" {
  let t = run(b"ab" + b"中", 2, 3)
  inspect(t.row_text(0), content="ab")
  inspect(t.row_text(1) == "中", content="true")
}

///|
test "cursor addressing is one based" {
  inspect(screen(b"\x1b[2;3HX", 3, 5), content="\n  X\n")
}

///|
test "cursor row and column move independently" {
  inspect(
    screen(b"\x1b[3;3H\x1b[2A\x1b[1DX", 4, 5),
    content=(
      #| X
      #|
      #|
      #|
    ),
  )
}

///|
test "cursor forward and back clamp at the margins" {
  inspect(
    screen(b"\x1b[99CX\x1b[99DY", 2, 4),
    content=(
      #|Y  X
      #|
    ),
  )
}

///|
test "next line and previous line reset the column" {
  inspect(screen(b"ab\x1b[Ecd", 3, 5), content="ab\ncd\n")
}

///|
test "column positioning is absolute" {
  inspect(
    screen(b"abcdef\x1b[3GX", 2, 8),
    content=(
      #|abXdef
      #|
    ),
  )
}

///|
test "erase to end of line" {
  inspect(
    screen(b"abcdef\x1b[1;4H\x1b[K", 2, 8),
    content=(
      #|abc
      #|
    ),
  )
}

///|
test "erase to start of line" {
  inspect(
    screen(b"abcdef\x1b[1;3H\x1b[1K", 2, 8),
    content=(
      #|   def
      #|
    ),
  )
}

///|
test "erase whole line" {
  inspect(
    screen(b"abcdef\x1b[2K", 2, 8),
    content=(
      #|
      #|
    ),
  )
}

///|
test "erase below keeps earlier rows" {
  inspect(
    screen(b"aa\r\nbb\r\ncc\x1b[2;1H\x1b[0J", 3, 4),
    content=(
      #|aa
      #|
      #|
    ),
  )
}

///|
test "erase above keeps later rows" {
  inspect(screen(b"aa\r\nbb\r\ncc\x1b[2;2H\x1b[1J", 3, 4), content="\n\ncc")
}

///|
test "erase display everything" {
  inspect(screen(b"aa\r\nbb\x1b[2J", 2, 4), content="\n")
}

///|
test "erase characters leaves the rest of the row alone" {
  inspect(
    screen(b"abcdef\x1b[1;2H\x1b[3X", 2, 8),
    content=(
      #|a   ef
      #|
    ),
  )
}

///|
test "delete characters pulls the row left" {
  inspect(
    screen(b"abcdef\x1b[1;2H\x1b[2P", 2, 8),
    content=(
      #|adef
      #|
    ),
  )
}

///|
test "insert characters pushes the row right" {
  inspect(
    screen(b"abcdef\x1b[1;2H\x1b[2@", 2, 8),
    content=(
      #|a  bcdef
      #|
    ),
  )
}

///|
test "indexed foreground colour is stored in the cell" {
  let c = cell_at(b"\x1b[31mX", 2, 4, 0, 0)
  inspect(c.fg, content="1")
  inspect(c.ch, content="X")
}

///|
test "bright colours use the upper palette entries" {
  inspect(cell_at(b"\x1b[91mX", 2, 4, 0, 0).fg, content="9")
}

///|
test "256 colour foreground" {
  inspect(cell_at(b"\x1b[38;5;208mX", 2, 4, 0, 0).fg, content="208")
}

///|
test "truecolour foreground packs into one int" {
  let c = cell_at(b"\x1b[38;2;18;52;86mX", 2, 4, 0, 0)
  inspect(color_is_rgb(c.fg), content="true")
  inspect(color_red(c.fg), content="18")
  inspect(color_green(c.fg), content="52")
  inspect(color_blue(c.fg), content="86")
}

///|
test "truecolour background is independent of the foreground" {
  let c = cell_at(b"\x1b[38;2;1;2;3m\x1b[48;2;4;5;6mX", 2, 4, 0, 0)
  inspect(color_blue(c.fg), content="3")
  inspect(color_blue(c.bg), content="6")
}

///|
test "sgr attributes accumulate and reset" {
  let c = cell_at(b"\x1b[1;4mX", 2, 4, 0, 0)
  inspect((c.flags & FLAG_BOLD) != 0, content="true")
  inspect((c.flags & FLAG_UNDERLINE) != 0, content="true")
  let d = cell_at(b"\x1b[1;4m\x1b[0mX", 2, 4, 0, 0)
  inspect(d.flags, content="0")
  inspect(d.fg, content="-1")
}

///|
test "sgr 22 clears only bold and dim" {
  let c = cell_at(b"\x1b[1;3;22mX", 2, 4, 0, 0)
  inspect((c.flags & FLAG_BOLD) != 0, content="false")
  inspect((c.flags & FLAG_ITALIC) != 0, content="true")
}

///|
test "a line feed at the bottom margin scrolls the region" {
  let bytes = b"a\r\nb\r\nc\r\nd\r\n"
  inspect(
    screen(bytes, 3, 4),
    content=(
      #|c
      #|d
      #|
    ),
  )
}

///|
test "scroll region confines the scroll" {
  // A region of rows 2..3 means the first row is never touched.
  inspect(
    screen(b"\x1b[2;3r\x1b[3;1Hx\r\ny", 4, 4),
    content=(
      #|
      #|x
      #|y
      #|
    ),
  )
}

///|
test "reverse index at the top margin scrolls down" {
  inspect(
    screen(b"a\r\nb\x1b[1;1H\x1bMX", 3, 4),
    content=(
      #|X
      #|a
      #|b
    ),
  )
}

///|
test "insert lines pushes content down" {
  inspect(screen(b"a\r\nb\r\nc\x1b[1;1H\x1b[L", 4, 4), content="\na\nb\nc")
}

///|
test "delete lines pulls content up" {
  inspect(
    screen(b"a\r\nb\r\nc\x1b[1;1H\x1b[M", 4, 4),
    content=(
      #|b
      #|c
      #|
      #|
    ),
  )
}

///|
test "save and restore cursor via ESC 7 and ESC 8" {
  inspect(
    screen(b"ab\x1b7\r\ncd\x1b8X", 3, 5),
    content=(
      #|abX
      #|cd
      #|
    ),
  )
}

///|
test "save and restore cursor via CSI s and CSI u" {
  inspect(
    screen(b"ab\x1b[s\r\ncd\x1b[uX", 3, 5),
    content=(
      #|abX
      #|cd
      #|
    ),
  )
}

///|
test "restoring without saving is a no-op" {
  inspect(screen(b"abc\x1b8", 2, 5), content="abc\n")
}

///|
test "the alternate screen starts blank and the primary survives" {
  let t = run(b"main\x1b[?1049hALT", 2, 8)
  inspect(t.is_on_alt(), content="true")
  inspect(t.row_text(0), content="ALT")
  t.feed(b"\x1b[?1049l")
  inspect(t.is_on_alt(), content="false")
  inspect(t.row_text(0), content="main")
}

///|
test "the alternate screen keeps the cursor out of the primary" {
  let t = run(b"ab\x1b[?25l", 2, 8)
  inspect(t.cursor_is_visible(), content="false")
  t.feed(b"\x1b[?25h")
  inspect(t.cursor_is_visible(), content="true")
}

///|
test "osc 2 sets the window title" {
  let t = run(b"\x1b]2;hello\x07", 2, 8)
  inspect(t.title_text(), content="hello")
  // and it draws nothing
  inspect(t.screen_text(), content="\n")
}

///|
test "osc 0 with a semicolon in the payload keeps it whole" {
  let t = run(b"\x1b]0;a;b\x07", 2, 8)
  inspect(t.title_text(), content="a;b")
}

///|
test "horizontal tab advances to the next stop" {
  inspect(
    screen(b"a\tb", 2, 16),
    content=(
      #|a       b
      #|
    ),
  )
}

///|
test "backspace moves left without erasing" {
  inspect(
    screen(b"abc\x08\x08X", 2, 5),
    content=(
      #|aXc
      #|
    ),
  )
}

///|
test "origin mode makes cursor addressing relative to the region" {
  inspect(
    screen(b"\x1b[2;4r\x1b[?6h\x1b[1;1HX", 5, 4),
    content=(
      #|
      #|X
      #|
      #|
      #|
    ),
  )
}

///|
test "a full reset clears the screen and the pen" {
  let t = run(b"\x1b[31mabc\r\ndef\x1b[2;2H\x1b[?1049h", 3, 5)
  inspect(t.is_on_alt(), content="true")
  t.feed(b"\x1bc")
  inspect(t.screen_text(), content="\n\n")
  inspect(t.is_on_alt(), content="false")
  let (cx, cy) = t.cursor()
  inspect(cx, content="0")
  inspect(cy, content="0")
  inspect(t.title_text(), content="")
}

///|
test "the screen is identical however the input is chunked" {
  let bytes = b"\x1b[1;31mhello \xe4\xb8\xad\x1b[0m\r\n\x1b[2;2Hsecond\x1b[K"
  let whole = screen(bytes, 4, 12)
  let mut size = 1
  while size <= 5 {
    let t = Terminal::new(4, 12)
    let n = bytes.length()
    let mut i = 0
    while i < n {
      let end = if i + size < n { i + size } else { n }
      t.feed(bytes.exact_view(start=i, end~).to_owned())
      i = i + size
    }
    t.finish()
    inspect(t.screen_text(), content=whole)
    size = size + 1
  }
}
