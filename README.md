<!-- Generated from README.mbt.md by tools/sync-readme.mjs — edit that file, not this one. -->

# MoonTerm

A terminal emulator core written in MoonBit.

MoonTerm takes a stream of bytes — the escape sequences a program writes to a
terminal — and maintains the screen those bytes describe: a grid of
characters, a cursor, a pen, a scroll region, and a history of the lines that
have scrolled off the top. It is the part of a terminal that decides *what is
on screen*. It does not draw anything, read from a pty, or know what a window
is.

That boundary is the whole point. Because the engine is a pure function from
bytes to a screen, it can be tested exhaustively: feed a stream to MoonTerm and
to a real terminal emulator, and compare the two screens cell by cell. The
project does exactly that, against xterm.js, on every commit.

```
        bytes ──▶ vt ──▶ term ──▶ render ──▶ text / ANSI / HTML
                 parse   screen   output
```

## What is implemented

The table below is the deliverable checklist: every sequence MoonTerm acts on,
and every sequence it deliberately does not. Anything absent from the "acted
on" column is consumed and ignored rather than corrupting the screen, which is
the behaviour a real terminal must have.

### Control sequences (`CSI`)

| Sequence | Final | Meaning |
| --- | --- | --- |
| `CSI n @` | `ICH` | Insert `n` blank characters |
| `CSI n A` | `CUU` | Cursor up `n` |
| `CSI n B` | `CUD` | Cursor down `n` |
| `CSI n C` | `CUF` | Cursor forward `n` |
| `CSI n D` | `CUB` | Cursor back `n` |
| `CSI n E` | `CNL` | Cursor to next line |
| `CSI n F` | `CPL` | Cursor to previous line |
| `CSI n G` | `CHA` | Cursor to column `n` |
| `CSI r ; c H` | `CUP` | Cursor position |
| `CSI r ; c f` | `HVP` | Cursor position (same as `CUP`) |
| `CSI n J` | `ED` | Erase in display (modes 0, 1, 2) |
| `CSI n K` | `EL` | Erase in line (modes 0, 1, 2) |
| `CSI n L` | `IL` | Insert `n` lines at the cursor |
| `CSI n M` | `DL` | Delete `n` lines at the cursor |
| `CSI n P` | `DCH` | Delete `n` characters |
| `CSI n S` | `SU` | Scroll up `n` lines |
| `CSI n T` | `SD` | Scroll down `n` lines |
| `CSI n X` | `ECH` | Erase `n` characters in place |
| `CSI n d` | `VPA` | Cursor to row `n` |
| `CSI n m` | `SGR` | Select graphic rendition |
| `CSI t ; b r` | `DECSTBM` | Set scrolling region |
| `CSI s` / `CSI u` | `SCOSC`/`SCORC` | Save / restore cursor |
| `CSI ? n h` / `CSI ? n l` | `DECSET`/`DECRST` | Set / reset DEC private mode |

`CUP` and `VPA` are clamped to the whole screen when origin mode is off and to
the scroll region when it is on. `CUU`/`CUD` are always bounded by the region,
whichever mode is in force — that is what the hardware terminals did, and it is
what xterm.js does.

### SGR attributes (`CSI n m`)

Reset (`0`), bold (`1`), dim (`2`), italic (`3`), underline (`4`), blink
(`5`, `6`), reverse (`7`), hidden (`8`), strike (`9`); the individual resets
`21`–`29`; the sixteen ANSI colours as `30`–`37`, `40`–`47`, `90`–`97`,
`100`–`107`; default foreground and background (`39`, `49`); and the extended
forms `38;5;n` / `48;5;n` (256-colour) and `38;2;r;g;b` / `48;2;r;g;b`
(truecolour).

### DEC private modes (`CSI ? n h/l`)

| Mode | Meaning |
| --- | --- |
| `6` | Origin mode — cursor addressing relative to the scroll region |
| `7` | Autowrap — wrap at the right margin |
| `25` | Cursor visibility |
| `47`, `1047` | Alternate screen buffer |
| `1049` | Alternate screen buffer, saving and restoring the cursor |

Every other private mode is accepted and ignored. `1` (application cursor
keys), `12` (cursor blink), `1000`–`1006` (mouse reporting) and `2004`
(bracketed paste) are tracked by real terminals but change nothing on screen, so
they need no state in a headless engine.

### Escape sequences (`ESC`)

| Sequence | Meaning |
| --- | --- |
| `ESC 7` / `ESC 8` | Save / restore cursor (`DECSC` / `DECRC`) |
| `ESC D` | Index — down one line, scrolling at the bottom margin |
| `ESC E` | Next line — carriage return and index |
| `ESC M` | Reverse index — up one line, scrolling at the top margin |
| `ESC c` | Full reset to the power-on state |

`ESC (` and `ESC #` sequences are parsed and ignored; they select character
sets, which a Unicode terminal does not need.

### Operating system commands (`OSC`)

`OSC 0` and `OSC 2` set the window title. Both `BEL` and `ESC \` terminate a
string. Every other OSC number is ignored.

### C0 controls

`BS`, `HT`, `LF`, `VT`, `FF` and `CR` all act. `BEL`, `SO` and `SI` are
consumed and ignored.

## The parser

`vt/` implements the DEC ANSI escape-sequence state machine as published by
Paul Williams, with all fourteen states. It is a pure transducer: bytes in,
five kinds of callback out, and no screen state of its own. That separation is
what lets the parser be tested against the specification tables directly, and
it is why `vt/` has no dependency on `term/`.

The parser is incremental. A chunk may be split at any byte — in the middle of
a CSI sequence, in the middle of a UTF-8 code point, in the middle of an OSC
payload — and the state survives across calls. Real terminal input arrives in
arbitrary chunks, so this is a correctness requirement rather than a nicety, and
the corpus tests two such split points explicitly.

UTF-8 decoding follows Unicode's "maximal subpart" rule: the longest prefix that
cannot become a valid sequence is reported as U+FFFD, and the byte that broke it
is reconsidered as the start of a new sequence. Overlong encodings, surrogates
and code points past U+10FFFF are all rejected — they are invalid UTF-8 even
when the byte structure looks well formed.

## Testing

```bash
moon test
```

151 tests, of which 45 are differential conformance cases.

### Differential testing against xterm.js

The conformance suite is the project's main quality claim, so it is worth being
precise about what it does.

`tools/oracle.mjs` holds a corpus of byte streams. It feeds each one to
xterm.js's headless emulator, reads the resulting screen cell by cell, and
writes `term/corpus_generated_wbtest.mbt` — a MoonBit test that feeds the same
bytes to MoonTerm and asserts the two screens match character for character,
along with the cursor position and whether the alternate screen is active.

```bash
node tools/oracle.mjs      # regenerate the corpus
moon test                  # verify against it
```

The generated file is committed deliberately. It means `moon test` alone proves
conformance — no Node.js in CI, no network — and it means the reference
behaviour is reviewable: a change in what xterm.js does shows up as a diff in a
file you can read, rather than as a test that quietly starts passing.

Three real bugs were found this way, none of which the existing unit tests had
noticed:

- **A pending wrap survived `CR` and `LF`.** The flag that makes the next
  character wrap at the right margin was cleared by cursor-addressing sequences
  but not by the control characters. A line that exactly filled the screen width
  and ended in `\r\n` therefore consumed two line feeds, scrolling the screen one
  line too far.
- **Leaving the alternate screen restored the wrong cursor.** `CSI ? 1049 l`
  saved the cursor on the way *out* as well as on the way in, so it restored the
  position it had just overwritten on the alternate screen. Programs like `vim`
  and `less` would have returned the cursor to the wrong place.
- **`CUP` was clamped to the scroll region.** Absolute positioning with origin
  mode off addresses the whole screen; MoonTerm was pulling any row below the
  region up to the region's bottom edge.

Each is fixed, and each has a corpus case that would catch it again.

### One deliberate difference from the reference

xterm.js reports `cursorX` as the column the *next* character would be written
to, so a cursor on the last column of the screen reports `cols`. MoonTerm
reports the index of the cell the cursor occupies, so the same state reports
`cols - 1` plus a pending-wrap flag. These describe the same terminal state, and
the visible screen is identical either way; the oracle normalises the reference
value before comparing, and `tools/oracle.mjs` says so where it does it. The
normalisation is the only one in the suite.

### Other tests

- `vt/` — the state machine against the specification tables, plus UTF-8
  decoding including truncated, overlong and surrogate inputs.
- `term/` — screen behaviour: scrolling, scroll regions, wide characters,
  erase modes, alt screen, save/restore.
- `render/` — round-trip tests. The screen is rendered to ANSI, fed back into a
  fresh terminal, and the two screens must be identical. A renderer that drops
  an attribute or emits operands in the wrong order fails this.

### Browser build

```bash
moon build --target js ./web
node tools/check-web.mjs
```

`web/` exposes the engine to JavaScript and `web/index.html` drives it. The
check script loads the same generated module the page loads and exercises the
whole exported surface from Node, so a broken binding is caught in CI instead of
showing up as a blank page.

## Running the demo

```bash
moon build --target js ./web
python3 -m http.server 8000     # any static server; ES modules need http, not file://
```

Then open `http://localhost:8000/web/`. Type escape sequences into the text box
(`ESC` and `BEL` are substituted with the real control bytes) or use the
presets, which cover wide characters, scrollback, the alternate screen, scroll
regions, the erase and insert/delete operations, and all three colour syntaxes.

## Using the engine

```mbt check
///|
test {
  let t = @term.Terminal::new(24, 80)
  t.feed(b"\x1b[31mred\x1b[0m plain")
  t.finish()
  assert_eq(t.row_text(0), "red plain")
}
```

`Terminal::feed` takes a `Bytes` chunk and may be called repeatedly.
`Terminal::finish` flushes a character left half-decoded by the end of the
stream. Read the screen back with `screen_text` (trimmed lines),
`screen_dump` (fixed-width, one character per column) or `row_text`; read
history with `scrollback_dump`.

`render/` turns a `Terminal` into output: `to_ansi` re-emits the screen as an
ANSI stream that reproduces it, `to_html` produces styled markup, and
`color_to_rgb` resolves a cell colour to RGB — including the 6×6×6 cube and the
greyscale ramp, whose levels are not evenly spaced.

## Architecture

| Package | Responsibility | Depends on |
| --- | --- | --- |
| `vt` | Byte stream → escape sequence callbacks. No screen state. | — |
| `term` | Screen: grid, cursor, pen, scroll region, scrollback. | `vt` |
| `render` | Screen → text, ANSI or HTML. | `term` |
| `web` | JavaScript entry points. No DOM access. | `term`, `render` |

The dependency graph is a line, not a web. `vt` can be tested without a screen;
`term` can be tested without an output format; `render` can be tested without a
browser. `web` is the only package that knows it might run in one, and even it
only returns strings — the page moves them into the DOM. That thin boundary is
why the demo needs no FFI bindings at all.

Colours and attributes are packed into `Int`s rather than stored as structs.
A MoonBit `struct` is a reference, so an attribute object stored per cell would
make every cell alias the same one; integers copy by value and keep cells
independent.

## Not implemented

Listed because a boundary you cannot see is worse than one you can.

- **Combining marks.** Zero-width characters are dropped rather than attached to
  the preceding cell. Wide characters are handled; grapheme clusters are not.
- **Character sets.** `ESC ( 0` and friends are parsed and ignored, so the DEC
  line-drawing characters are not remapped from ASCII.
- **Mouse reporting and bracketed paste.** The modes are accepted and ignored;
  the engine has no input side to report events to.
- **DCS payloads.** Framing is parsed correctly so the surrounding stream stays
  in sync, but the payload is discarded — so sixel, ReGIS and the kitty graphics
  protocol are not rendered.
- **Reflow on resize.** Resizing keeps the top-left corner. xterm.js reflows
  wrapped lines; doing that well is a project in itself.
- **Configurable tab stops.** Tabs advance to fixed multiples of eight; `HTS`
  and `TBC` are not implemented.
- **Scrollback viewing.** History accumulates and is readable through the API,
  but there is no viewport that scrolls into it.

## Roadmap

In rough order of how much they would add:

1. Combining marks and grapheme clusters, to close the largest correctness gap.
2. `DCS` payload handling, which unlocks sixel and the kitty graphics protocol.
3. Reflow on resize.
4. Configurable tab stops.
5. A scrollback viewport, so history is reachable interactively.

## Provenance

MoonTerm is an original implementation, not a port. Every line under `vt/`,
`term/`, `render/` and `web/` was written for this project. No code was copied
or translated from another terminal emulator, and nothing is vendored.

This matters because MoonBit's package registry already contains modules in
this space, and it is worth being precise about how they differ:

| Module | What it is | Relationship to MoonTerm |
| --- | --- | --- |
| `tonyfettes/libghostty-vt` | MoonBit bindings to Ghostty's C VT library | FFI binding; MoonTerm depends on neither |
| `tonyfettes/ghostty` | MoonBit bindings to Ghostty | FFI binding |
| `tonyfettes/vte` | MoonBit bindings to GNOME VTE (GTK4) | FFI binding |
| `tonyfettes/rabbita_xterm` | MoonBit bindings to xterm.js | FFI binding to a JavaScript terminal |
| `mizchi/tui-terminal-protocol` | ANSI escape *encoders* | Output side only: it writes sequences, it does not parse them |

Every one of those wraps an existing C or JavaScript terminal emulator. MoonTerm
is a parser and screen model written directly in MoonBit, with no C or
JavaScript runtime underneath it. That is what makes the differential testing in
[Testing](#testing) possible at all: there is no upstream implementation to
delegate to, so conformance has to be established by comparing against a
separate emulator rather than assumed from the library being wrapped.

The only third-party code involved in the project is:

- **`@xterm/headless`** (xterm.js), used *exclusively* as a test oracle in
  `tools/oracle.mjs`. It is never linked into MoonTerm — it runs in Node.js,
  produces the expected screens, and those screens are committed as plain data.
  MoonTerm has no runtime dependency on it, and `moon test` passes with Node.js
  absent.
- **`moonbitlang/core`**, the MoonBit standard library, used for `String`,
  `Array`, `StringBuilder` and UTF-8 encoding. Apache-2.0.

## Use of AI tools

Artificial intelligence assisted with the implementation of this project. The
project's goals, its architecture, and the decision about what counts as
evidence of correctness were set by the author, and the author is responsible
for the result.

What that division means in practice here: correctness is not asserted on the
authority of a code generator. It is established by `tools/oracle.mjs`, which
compares MoonTerm against xterm.js cell by cell, and by a committed corpus that
CI regenerates and diffs so the expected values cannot be quietly edited. That
harness found three real bugs in code that already passed its unit tests — a
pending wrap surviving `CR`/`LF`, the alternate screen restoring the wrong
cursor, and `CUP` being clamped to the scroll region — and each is documented
in [Testing](#testing) with the fix and a regression case. Code that passes
generated expectations but fails the reference is a bug, and the tooling is
arranged so that outcome is visible rather than hidden.

## References

- Paul Williams, *A parser for ANSI* — the state machine `vt/` implements.
- ECMA-48, *Control Functions for Coded Character Sets*.
- `xterm`'s `ctlseqs` document — the reference for DEC private modes.
- The Unicode Standard, *East Asian Width*, for the width tables approximated in
  `term/attr.mbt`.
- xterm.js, whose headless emulator is the differential-test oracle.

## License

Apache-2.0. See [LICENSE](LICENSE).
