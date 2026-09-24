// GENERATED FILE — do not edit.
//
// Differential conformance tests: each case feeds a byte stream to MoonTerm
// and asserts the resulting screen matches what xterm.js produces for the
// same input. Regenerate with:
//
//     node tools/oracle.mjs
//
// Source of truth for the corpus is the `corpus` array in tools/oracle.mjs.
// 45 cases.
///|
/// plain ascii text
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "plain ascii text" {
  let t = Terminal::new(3, 20)
  t.feed(b"\x68\x65\x6C\x6C\x6F\x20\x77\x6F\x72\x6C\x64")
  t.finish()
  assert_eq(t.screen_dump(), "hello world         \n                    \n                    ")
  assert_eq(t.cursor(), (11, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// autowrap at right margin
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "autowrap at right margin" {
  let t = Terminal::new(4, 10)
  t.feed(b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77")
  t.finish()
  assert_eq(t.screen_dump(), "abcdefghij\nklmnopqrst\nuvw       \n          ")
  assert_eq(t.cursor(), (3, 2))
  assert_eq(t.is_on_alt(), false)
}

///|
/// exactly filling the last column does not scroll
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "exactly filling the last column does not scroll" {
  let t = Terminal::new(3, 10)
  t.feed(b"\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39")
  t.finish()
  assert_eq(t.screen_dump(), "0123456789\n          \n          ")
  assert_eq(t.cursor(), (9, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// one past the last column scrolls
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "one past the last column scrolls" {
  let t = Terminal::new(3, 10)
  t.feed(b"\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x58")
  t.finish()
  assert_eq(t.screen_dump(), "0123456789\nX         \n          ")
  assert_eq(t.cursor(), (1, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// carriage return and line feed
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "carriage return and line feed" {
  let t = Terminal::new(4, 12)
  t.feed(b"\x6F\x6E\x65\x0D\x74\x77\x6F\x0D\x0A\x74\x68\x72\x65\x65")
  t.finish()
  assert_eq(t.screen_dump(), "two         \nthree       \n            \n            ")
  assert_eq(t.cursor(), (5, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// backspace overwrites
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "backspace overwrites" {
  let t = Terminal::new(3, 12)
  t.feed(b"\x61\x62\x63\x08\x08\x58\x59")
  t.finish()
  assert_eq(t.screen_dump(), "aXY         \n            \n            ")
  assert_eq(t.cursor(), (3, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// horizontal tab stops
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "horizontal tab stops" {
  let t = Terminal::new(3, 24)
  t.feed(b"\x61\x09\x62\x09\x63\x09\x64")
  t.finish()
  assert_eq(t.screen_dump(), "a       b       c      d\n                        \n                        ")
  assert_eq(t.cursor(), (23, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// cursor position CUP
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "cursor position CUP" {
  let t = Terminal::new(6, 20)
  t.feed(b"\x1B\x5B\x33\x3B\x35\x48\x58\x1B\x5B\x31\x3B\x31\x48\x59\x1B\x5B\x36\x3B\x32\x30\x48\x5A")
  t.finish()
  assert_eq(t.screen_dump(), "Y                   \n                    \n    X               \n                    \n                    \n                   Z")
  assert_eq(t.cursor(), (19, 5))
  assert_eq(t.is_on_alt(), false)
}

///|
/// cursor up down forward back
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "cursor up down forward back" {
  let t = Terminal::new(8, 20)
  t.feed(b"\x1B\x5B\x35\x3B\x35\x48\x2A\x1B\x5B\x32\x41\x5E\x1B\x5B\x33\x42\x76\x1B\x5B\x34\x44\x3C\x1B\x5B\x32\x43\x3E")
  t.finish()
  assert_eq(t.screen_dump(), "                    \n                    \n     ^              \n                    \n    *               \n   <  >             \n                    \n                    ")
  assert_eq(t.cursor(), (7, 5))
  assert_eq(t.is_on_alt(), false)
}

///|
/// cursor horizontal absolute CHA
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "cursor horizontal absolute CHA" {
  let t = Terminal::new(3, 20)
  t.feed(b"\x1B\x5B\x31\x30\x47\x61\x1B\x5B\x31\x47\x62\x1B\x5B\x32\x30\x47\x63")
  t.finish()
  assert_eq(t.screen_dump(), "b        a         c\n                    \n                    ")
  assert_eq(t.cursor(), (19, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// vertical absolute VPA
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "vertical absolute VPA" {
  let t = Terminal::new(6, 10)
  t.feed(b"\x1B\x5B\x33\x64\x61\x1B\x5B\x31\x64\x62\x1B\x5B\x36\x64\x63")
  t.finish()
  assert_eq(t.screen_dump(), " b        \n          \na         \n          \n          \n  c       ")
  assert_eq(t.cursor(), (3, 5))
  assert_eq(t.is_on_alt(), false)
}

///|
/// cursor next and previous line
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "cursor next and previous line" {
  let t = Terminal::new(6, 20)
  t.feed(b"\x1B\x5B\x32\x3B\x35\x48\x61\x1B\x5B\x32\x45\x62\x1B\x5B\x31\x46\x63")
  t.finish()
  assert_eq(t.screen_dump(), "                    \n    a               \nc                   \nb                   \n                    \n                    ")
  assert_eq(t.cursor(), (1, 2))
  assert_eq(t.is_on_alt(), false)
}

///|
/// erase in line EL modes
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "erase in line EL modes" {
  let t = Terminal::new(4, 12)
  t.feed(b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x31\x3B\x34\x48\x1B\x5B\x30\x4B\x0D\x0A\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x32\x3B\x34\x48\x1B\x5B\x31\x4B\x0D\x0A\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x33\x3B\x34\x48\x1B\x5B\x32\x4B")
  t.finish()
  assert_eq(t.screen_dump(), "abc         \n    efghijkl\n            \n            ")
  assert_eq(t.cursor(), (3, 2))
  assert_eq(t.is_on_alt(), false)
}

///|
/// erase in display ED modes
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "erase in display ED modes" {
  let t = Terminal::new(4, 12)
  t.feed(b"\x61\x61\x61\x61\x61\x61\x61\x61\x61\x61\x61\x61\x0D\x0A\x62\x62\x62\x62\x62\x62\x62\x62\x62\x62\x62\x62\x0D\x0A\x63\x63\x63\x63\x63\x63\x63\x63\x63\x63\x63\x63\x0D\x0A\x64\x64\x64\x64\x64\x64\x64\x64\x64\x64\x64\x64\x1B\x5B\x32\x3B\x34\x48\x1B\x5B\x30\x4A")
  t.finish()
  assert_eq(t.screen_dump(), "aaaaaaaaaaaa\nbbb         \n            \n            ")
  assert_eq(t.cursor(), (3, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// insert and delete characters
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "insert and delete characters" {
  let t = Terminal::new(3, 12)
  t.feed(b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x31\x3B\x33\x48\x1B\x5B\x32\x40\x1B\x5B\x31\x3B\x33\x48\x1B\x5B\x33\x50")
  t.finish()
  assert_eq(t.screen_dump(), "abdefghij   \n            \n            ")
  assert_eq(t.cursor(), (2, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// erase characters ECH
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "erase characters ECH" {
  let t = Terminal::new(3, 12)
  t.feed(b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x31\x3B\x34\x48\x1B\x5B\x33\x58")
  t.finish()
  assert_eq(t.screen_dump(), "abc   ghijkl\n            \n            ")
  assert_eq(t.cursor(), (3, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// insert and delete lines
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "insert and delete lines" {
  let t = Terminal::new(5, 10)
  t.feed(b"\x4C\x31\x0D\x0A\x4C\x32\x0D\x0A\x4C\x33\x0D\x0A\x4C\x34\x0D\x0A\x4C\x35\x1B\x5B\x32\x3B\x31\x48\x1B\x5B\x31\x4C")
  t.finish()
  assert_eq(t.screen_dump(), "L1        \n          \nL2        \nL3        \nL4        ")
  assert_eq(t.cursor(), (0, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// delete lines
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "delete lines" {
  let t = Terminal::new(5, 10)
  t.feed(b"\x4C\x31\x0D\x0A\x4C\x32\x0D\x0A\x4C\x33\x0D\x0A\x4C\x34\x0D\x0A\x4C\x35\x1B\x5B\x32\x3B\x31\x48\x1B\x5B\x31\x4D")
  t.finish()
  assert_eq(t.screen_dump(), "L1        \nL3        \nL4        \nL5        \n          ")
  assert_eq(t.cursor(), (0, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// scroll region confines line feed
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "scroll region confines line feed" {
  let t = Terminal::new(6, 10)
  t.feed(b"\x74\x6F\x70\x0D\x0A\x1B\x5B\x32\x3B\x34\x72\x1B\x5B\x34\x3B\x31\x48\x6D\x69\x64\x0D\x0A\x0D\x0A\x0D\x0A\x0D\x0A\x1B\x5B\x36\x3B\x31\x48\x62\x6F\x74\x74\x6F\x6D")
  t.finish()
  assert_eq(t.screen_dump(), "top       \n          \n          \n          \n          \nbottom    ")
  assert_eq(t.cursor(), (6, 5))
  assert_eq(t.is_on_alt(), false)
}

///|
/// scroll up and down within region
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "scroll up and down within region" {
  let t = Terminal::new(6, 10)
  t.feed(b"\x41\x0D\x0A\x42\x0D\x0A\x43\x0D\x0A\x44\x0D\x0A\x45\x0D\x0A\x46\x1B\x5B\x32\x3B\x35\x72\x1B\x5B\x32\x3B\x31\x48\x1B\x5B\x32\x53\x1B\x5B\x32\x54")
  t.finish()
  assert_eq(t.screen_dump(), "A         \n          \n          \nD         \nE         \nF         ")
  assert_eq(t.cursor(), (0, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// save and restore cursor DECSC DECRC
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "save and restore cursor DECSC DECRC" {
  let t = Terminal::new(5, 16)
  t.feed(b"\x1B\x5B\x32\x3B\x34\x48\x1B\x37\x1B\x5B\x35\x3B\x31\x48\x6D\x6F\x76\x65\x64\x1B\x38\x62\x61\x63\x6B")
  t.finish()
  assert_eq(t.screen_dump(), "                \n   back         \n                \n                \nmoved           ")
  assert_eq(t.cursor(), (7, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// save and restore cursor CSI s u
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "save and restore cursor CSI s u" {
  let t = Terminal::new(5, 16)
  t.feed(b"\x1B\x5B\x32\x3B\x34\x48\x1B\x5B\x73\x1B\x5B\x35\x3B\x31\x48\x6D\x6F\x76\x65\x64\x1B\x5B\x75\x62\x61\x63\x6B")
  t.finish()
  assert_eq(t.screen_dump(), "                \n   back         \n                \n                \nmoved           ")
  assert_eq(t.cursor(), (7, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// alternate screen 1049
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "alternate screen 1049" {
  let t = Terminal::new(4, 14)
  t.feed(b"\x70\x72\x69\x6D\x61\x72\x79\x1B\x5B\x3F\x31\x30\x34\x39\x68\x1B\x5B\x31\x3B\x31\x48\x61\x6C\x74\x1B\x5B\x3F\x31\x30\x34\x39\x6C")
  t.finish()
  assert_eq(t.screen_dump(), "primary       \n              \n              \n              ")
  assert_eq(t.cursor(), (7, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// alternate screen 47 leaves cursor alone
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "alternate screen 47 leaves cursor alone" {
  let t = Terminal::new(4, 14)
  t.feed(b"\x70\x72\x69\x6D\x61\x72\x79\x1B\x5B\x3F\x34\x37\x68\x1B\x5B\x31\x3B\x31\x48\x61\x6C\x74\x1B\x5B\x32\x3B\x33\x48\x78\x1B\x5B\x3F\x34\x37\x6C")
  t.finish()
  assert_eq(t.screen_dump(), "primary       \n              \n              \n              ")
  assert_eq(t.cursor(), (3, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// origin mode confines CUP to region
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "origin mode confines CUP to region" {
  let t = Terminal::new(6, 12)
  t.feed(b"\x1B\x5B\x32\x3B\x34\x72\x1B\x5B\x3F\x36\x68\x1B\x5B\x31\x3B\x31\x48\x58\x1B\x5B\x39\x3B\x39\x48\x59")
  t.finish()
  assert_eq(t.screen_dump(), "            \nX           \n            \n        Y   \n            \n            ")
  assert_eq(t.cursor(), (9, 3))
  assert_eq(t.is_on_alt(), false)
}

///|
/// autowrap disabled truncates at margin
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "autowrap disabled truncates at margin" {
  let t = Terminal::new(3, 10)
  t.feed(b"\x1B\x5B\x3F\x37\x6C\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70")
  t.finish()
  assert_eq(t.screen_dump(), "abcdefghip\n          \n          ")
  assert_eq(t.cursor(), (9, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// SGR colors do not disturb text
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "SGR colors do not disturb text" {
  let t = Terminal::new(3, 20)
  t.feed(b"\x1B\x5B\x33\x31\x6D\x72\x65\x64\x20\x1B\x5B\x34\x32\x6D\x67\x72\x65\x65\x6E\x20\x62\x67\x20\x1B\x5B\x30\x6D\x70\x6C\x61\x69\x6E")
  t.finish()
  assert_eq(t.screen_dump(), "red green bg plain  \n                    \n                    ")
  assert_eq(t.cursor(), (18, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// SGR 256 colour and truecolour
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "SGR 256 colour and truecolour" {
  let t = Terminal::new(3, 24)
  t.feed(b"\x1B\x5B\x33\x38\x3B\x35\x3B\x31\x39\x36\x6D\x78\x1B\x5B\x34\x38\x3B\x35\x3B\x32\x31\x6D\x79\x1B\x5B\x33\x38\x3B\x32\x3B\x31\x30\x3B\x32\x30\x3B\x33\x30\x6D\x7A\x1B\x5B\x30\x6D")
  t.finish()
  assert_eq(t.screen_dump(), "xyz                     \n                        \n                        ")
  assert_eq(t.cursor(), (3, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// SGR attributes then reset
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "SGR attributes then reset" {
  let t = Terminal::new(3, 20)
  t.feed(b"\x1B\x5B\x31\x3B\x33\x3B\x34\x6D\x62\x6F\x6C\x64\x20\x1B\x5B\x32\x32\x3B\x32\x33\x3B\x32\x34\x6D\x6E\x6F\x72\x6D\x61\x6C")
  t.finish()
  assert_eq(t.screen_dump(), "bold normal         \n                    \n                    ")
  assert_eq(t.cursor(), (11, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// selective erase keeps characters outside range
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "selective erase keeps characters outside range" {
  let t = Terminal::new(3, 12)
  t.feed(b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x1B\x5B\x31\x3B\x33\x48\x1B\x5B\x31\x4B\x1B\x5B\x31\x3B\x31\x48\x78\x79\x7A")
  t.finish()
  assert_eq(t.screen_dump(), "xyzdefghijkl\n            \n            ")
  assert_eq(t.cursor(), (3, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// wide CJK characters occupy two cells
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "wide CJK characters occupy two cells" {
  let t = Terminal::new(3, 12)
  t.feed(b"\xE4\xB8\xAD\xE6\x96\x87\xE6\xB5\x8B\xE8\xAF\x95")
  t.finish()
  assert_eq(t.screen_dump(), "\u{4E2D}\u{6587}\u{6D4B}\u{8BD5}    \n            \n            ")
  assert_eq(t.cursor(), (8, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// wide characters wrap as a unit
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "wide characters wrap as a unit" {
  let t = Terminal::new(4, 5)
  t.feed(b"\xE4\xB8\xAD\xE4\xB8\xAD\xE4\xB8\xAD\xE4\xB8\xAD")
  t.finish()
  assert_eq(t.screen_dump(), "\u{4E2D}\u{4E2D} \n\u{4E2D}\u{4E2D} \n     \n     ")
  assert_eq(t.cursor(), (4, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// wide character at the right margin wraps whole
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "wide character at the right margin wraps whole" {
  let t = Terminal::new(4, 6)
  t.feed(b"\x61\x62\x63\x64\x65\xE4\xB8\xAD")
  t.finish()
  assert_eq(t.screen_dump(), "abcde \n\u{4E2D}    \n      \n      ")
  assert_eq(t.cursor(), (2, 1))
  assert_eq(t.is_on_alt(), false)
}

///|
/// OSC title change is not printed
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "OSC title change is not printed" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x1B\x5D\x30\x3B\x6D\x79\x20\x74\x69\x74\x6C\x65\x07\x76\x69\x73\x69\x62\x6C\x65")
  t.finish()
  assert_eq(t.screen_dump(), "visible         \n                \n                ")
  assert_eq(t.cursor(), (7, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// OSC terminated by ST
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "OSC terminated by ST" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x1B\x5D\x32\x3B\x74\x69\x74\x6C\x65\x1B\x5C\x76\x69\x73\x69\x62\x6C\x65")
  t.finish()
  assert_eq(t.screen_dump(), "visible         \n                \n                ")
  assert_eq(t.cursor(), (7, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// unknown CSI is ignored without corrupting screen
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "unknown CSI is ignored without corrupting screen" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x61\x1B\x5B\x39\x39\x3B\x39\x39\x3B\x39\x39\x7A\x62")
  t.finish()
  assert_eq(t.screen_dump(), "ab              \n                \n                ")
  assert_eq(t.cursor(), (2, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// malformed CSI with subparameter is discarded
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "malformed CSI with subparameter is discarded" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x61\x1B\x5B\x31\x3A\x32\x6D\x62")
  t.finish()
  assert_eq(t.screen_dump(), "ab              \n                \n                ")
  assert_eq(t.cursor(), (2, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// ESC c full reset
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "ESC c full reset" {
  let t = Terminal::new(3, 10)
  t.feed(b"\x64\x69\x72\x74\x79\x1B\x5B\x35\x3B\x33\x48\x78\x1B\x63")
  t.finish()
  assert_eq(t.screen_dump(), "          \n          \n          ")
  assert_eq(t.cursor(), (0, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// DCS payload is consumed silently
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "DCS payload is consumed silently" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x61\x1B\x50\x31\x3B\x32\x3B\x33\x21\x7C\x70\x61\x79\x6C\x6F\x61\x64\x1B\x5C\x62")
  t.finish()
  assert_eq(t.screen_dump(), "ab              \n                \n                ")
  assert_eq(t.cursor(), (2, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// cursor visibility DECRST 25 is state only
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "cursor visibility DECRST 25 is state only" {
  let t = Terminal::new(3, 10)
  t.feed(b"\x61\x62\x1B\x5B\x3F\x32\x35\x6C\x63")
  t.finish()
  assert_eq(t.screen_dump(), "abc       \n          \n          ")
  assert_eq(t.cursor(), (3, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// chunk boundary inside a CSI sequence
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "chunk boundary inside a CSI sequence" {
  let t = Terminal::new(3, 16)
  t.feed(b"\x1B\x5B\x33")
  t.feed(b"\x3B\x34\x48\x58")
  t.finish()
  assert_eq(t.screen_dump(), "                \n                \n   X            ")
  assert_eq(t.cursor(), (4, 2))
  assert_eq(t.is_on_alt(), false)
}

///|
/// chunk boundary inside a UTF-8 code point
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "chunk boundary inside a UTF-8 code point" {
  let t = Terminal::new(3, 12)
  t.feed(b"\xE4\xB8\xAD\xE6")
  t.feed(b"\x96\x87\xE5\xAD\x97")
  t.finish()
  assert_eq(t.screen_dump(), "\u{4E2D}\u{6587}\u{5B57}      \n            \n            ")
  assert_eq(t.cursor(), (6, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// reverse index at top of screen
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "reverse index at top of screen" {
  let t = Terminal::new(4, 12)
  t.feed(b"\x61\x0D\x0A\x62\x0D\x0A\x63\x1B\x4D\x1B\x4D")
  t.finish()
  assert_eq(t.screen_dump(), "a           \nb           \nc           \n            ")
  assert_eq(t.cursor(), (1, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// CUP clamps beyond screen bounds
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "CUP clamps beyond screen bounds" {
  let t = Terminal::new(4, 10)
  t.feed(b"\x1B\x5B\x39\x39\x3B\x39\x39\x48\x58\x1B\x5B\x31\x3B\x31\x48\x59")
  t.finish()
  assert_eq(t.screen_dump(), "Y         \n          \n          \n         X")
  assert_eq(t.cursor(), (1, 0))
  assert_eq(t.is_on_alt(), false)
}

///|
/// repeated SGR runs accumulate then clear
///
/// Reference screen captured from xterm.js @xterm/headless by
/// `node tools/oracle.mjs`. Do not edit by hand.
test "repeated SGR runs accumulate then clear" {
  let t = Terminal::new(3, 24)
  t.feed(b"\x1B\x5B\x31\x6D\x1B\x5B\x34\x6D\x1B\x5B\x33\x31\x6D\x61\x62\x63\x1B\x5B\x32\x32\x6D\x64\x65\x66\x1B\x5B\x32\x34\x6D\x67\x68\x69\x1B\x5B\x33\x39\x6D\x6A\x6B\x6C")
  t.finish()
  assert_eq(t.screen_dump(), "abcdefghijkl            \n                        \n                        ")
  assert_eq(t.cursor(), (12, 0))
  assert_eq(t.is_on_alt(), false)
}
