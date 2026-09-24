// Differential-test oracle for MoonTerm.
//
// MoonTerm's core claim is that its screen state matches a real terminal
// emulator for the sequence subset it implements. This script is how that
// claim is checked rather than asserted: it feeds a corpus of byte streams
// through xterm.js's headless emulator, records the resulting screen, and
// emits a MoonBit test file that asserts MoonTerm produces byte-identical
// screens for the same input.
//
// Run `node tools/oracle.mjs` to regenerate `term/corpus_generated_wbtest.mbt`.
// The generated file is committed on purpose: `moon test` alone then proves
// conformance, with no Node.js needed in CI, and the diff of the generated
// file is a reviewable record of what the reference emulator actually does.

// @xterm/headless is CommonJS, so the named exports are not statically visible
// to the ESM loader; destructure them off the default export instead.
import xtermHeadless from '@xterm/headless';
const { Terminal } = xtermHeadless;
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'term', 'corpus_generated_wbtest.mbt');

// ---------------------------------------------------------------------------
// Corpus
//
// Every entry is a raw byte stream as a JS string. `\x1b` is ESC; multi-byte
// UTF-8 is handled by encoding the whole string as UTF-8, so CJK and emoji can
// be written literally.
// ---------------------------------------------------------------------------

const ESC = '\x1b';
const CSI = `${ESC}[`;
const OSC = `${ESC}]`;

const corpus = [
  {
    name: 'plain ascii text',
    cols: 20,
    rows: 3,
    input: 'hello world',
  },
  {
    name: 'autowrap at right margin',
    cols: 10,
    rows: 4,
    input: 'abcdefghijklmnopqrstuvw',
  },
  {
    name: 'exactly filling the last column does not scroll',
    cols: 10,
    rows: 3,
    input: '0123456789',
  },
  {
    name: 'one past the last column scrolls',
    cols: 10,
    rows: 3,
    input: '0123456789X',
  },
  {
    name: 'carriage return and line feed',
    cols: 12,
    rows: 4,
    input: 'one\rtwo\r\nthree',
  },
  {
    name: 'backspace overwrites',
    cols: 12,
    rows: 3,
    input: 'abc\b\bXY',
  },
  {
    name: 'horizontal tab stops',
    cols: 24,
    rows: 3,
    input: 'a\tb\tc\td',
  },
  {
    name: 'cursor position CUP',
    cols: 20,
    rows: 6,
    input: `${CSI}3;5HX${CSI}1;1HY${CSI}6;20HZ`,
  },
  {
    name: 'cursor up down forward back',
    cols: 20,
    rows: 8,
    input: `${CSI}5;5H*${CSI}2A^${CSI}3Bv${CSI}4D<${CSI}2C>`,
  },
  {
    name: 'cursor horizontal absolute CHA',
    cols: 20,
    rows: 3,
    input: `${CSI}10Ga${CSI}1Gb${CSI}20Gc`,
  },
  {
    name: 'vertical absolute VPA',
    cols: 10,
    rows: 6,
    input: `${CSI}3da${CSI}1db${CSI}6dc`,
  },
  {
    name: 'cursor next and previous line',
    cols: 20,
    rows: 6,
    input: `${CSI}2;5Ha${CSI}2Eb${CSI}1Fc`,
  },
  {
    name: 'erase in line EL modes',
    cols: 12,
    rows: 4,
    input: `abcdefghijkl${CSI}1;4H${CSI}0K\r\nabcdefghijkl${CSI}2;4H${CSI}1K\r\nabcdefghijkl${CSI}3;4H${CSI}2K`,
  },
  {
    name: 'erase in display ED modes',
    cols: 12,
    rows: 4,
    input: `aaaaaaaaaaaa\r\nbbbbbbbbbbbb\r\ncccccccccccc\r\ndddddddddddd${CSI}2;4H${CSI}0J`,
  },
  {
    name: 'insert and delete characters',
    cols: 12,
    rows: 3,
    input: `abcdefghijkl${CSI}1;3H${CSI}2@${CSI}1;3H${CSI}3P`,
  },
  {
    name: 'erase characters ECH',
    cols: 12,
    rows: 3,
    input: `abcdefghijkl${CSI}1;4H${CSI}3X`,
  },
  {
    name: 'insert and delete lines',
    cols: 10,
    rows: 5,
    input: `L1\r\nL2\r\nL3\r\nL4\r\nL5${CSI}2;1H${CSI}1L`,
  },
  {
    name: 'delete lines',
    cols: 10,
    rows: 5,
    input: `L1\r\nL2\r\nL3\r\nL4\r\nL5${CSI}2;1H${CSI}1M`,
  },
  {
    name: 'scroll region confines line feed',
    cols: 10,
    rows: 6,
    input: `top\r\n${CSI}2;4r${CSI}4;1Hmid\r\n\r\n\r\n\r\n${CSI}6;1Hbottom`,
  },
  {
    name: 'scroll up and down within region',
    cols: 10,
    rows: 6,
    input: `A\r\nB\r\nC\r\nD\r\nE\r\nF${CSI}2;5r${CSI}2;1H${CSI}2S${CSI}2T`,
  },
  {
    name: 'save and restore cursor DECSC DECRC',
    cols: 16,
    rows: 5,
    input: `${CSI}2;4H${ESC}7${CSI}5;1Hmoved${ESC}8back`,
  },
  {
    name: 'save and restore cursor CSI s u',
    cols: 16,
    rows: 5,
    input: `${CSI}2;4H${CSI}s${CSI}5;1Hmoved${CSI}uback`,
  },
  {
    name: 'alternate screen 1049',
    cols: 14,
    rows: 4,
    input: `primary${CSI}?1049h${CSI}1;1Halt${CSI}?1049l`,
  },
  {
    name: 'alternate screen 47 leaves cursor alone',
    cols: 14,
    rows: 4,
    input: `primary${CSI}?47h${CSI}1;1Halt${CSI}2;3Hx${CSI}?47l`,
  },
  {
    name: 'origin mode confines CUP to region',
    cols: 12,
    rows: 6,
    input: `${CSI}2;4r${CSI}?6h${CSI}1;1HX${CSI}9;9HY`,
  },
  {
    name: 'autowrap disabled truncates at margin',
    cols: 10,
    rows: 3,
    input: `${CSI}?7labcdefghijklmnop`,
  },
  {
    name: 'SGR colors do not disturb text',
    cols: 20,
    rows: 3,
    input: `${CSI}31mred ${CSI}42mgreen bg ${CSI}0mplain`,
  },
  {
    name: 'SGR 256 colour and truecolour',
    cols: 24,
    rows: 3,
    input: `${CSI}38;5;196mx${CSI}48;5;21my${CSI}38;2;10;20;30mz${CSI}0m`,
  },
  {
    name: 'SGR attributes then reset',
    cols: 20,
    rows: 3,
    input: `${CSI}1;3;4mbold ${CSI}22;23;24mnormal`,
  },
  {
    name: 'selective erase keeps characters outside range',
    cols: 12,
    rows: 3,
    input: `abcdefghijkl${CSI}1;3H${CSI}1K${CSI}1;1Hxyz`,
  },
  {
    name: 'wide CJK characters occupy two cells',
    cols: 12,
    rows: 3,
    input: '中文测试',
  },
  {
    name: 'wide characters wrap as a unit',
    cols: 5,
    rows: 4,
    input: '中中中中',
  },
  {
    name: 'wide character at the right margin wraps whole',
    cols: 6,
    rows: 4,
    input: 'abcde中',
  },
  {
    name: 'OSC title change is not printed',
    cols: 16,
    rows: 3,
    input: `${OSC}0;my title\x07visible`,
  },
  {
    name: 'OSC terminated by ST',
    cols: 16,
    rows: 3,
    input: `${OSC}2;title${ESC}\\visible`,
  },
  {
    name: 'unknown CSI is ignored without corrupting screen',
    cols: 16,
    rows: 3,
    input: `a${CSI}99;99;99zb`,
  },
  {
    name: 'malformed CSI with subparameter is discarded',
    cols: 16,
    rows: 3,
    input: `a${CSI}1:2mb`,
  },
  {
    name: 'ESC c full reset',
    cols: 10,
    rows: 3,
    input: `dirty${CSI}5;3Hx${ESC}c`,
  },
  {
    name: 'DCS payload is consumed silently',
    cols: 16,
    rows: 3,
    input: `a${ESC}P1;2;3!|payload${ESC}\\b`,
  },
  {
    name: 'cursor visibility DECRST 25 is state only',
    cols: 10,
    rows: 3,
    input: `ab${CSI}?25lc`,
  },
  {
    name: 'chunk boundary inside a CSI sequence',
    cols: 16,
    rows: 3,
    // Fed as two separate writes by the driver below; see `splitAt`.
    input: `${CSI}3;4HX`,
    splitAt: 3,
  },
  {
    name: 'chunk boundary inside a UTF-8 code point',
    cols: 12,
    rows: 3,
    input: '中文字',
    splitAt: 4,
  },
  {
    name: 'reverse index at top of screen',
    cols: 12,
    rows: 4,
    input: `a\r\nb\r\nc${ESC}M${ESC}M`,
  },
  {
    name: 'CUP clamps beyond screen bounds',
    cols: 10,
    rows: 4,
    input: `${CSI}99;99HX${CSI}1;1HY`,
  },
  {
    name: 'repeated SGR runs accumulate then clear',
    cols: 24,
    rows: 3,
    input: `${CSI}1m${CSI}4m${CSI}31mabc${CSI}22mdef${CSI}24mghi${CSI}39mjkl`,
  },
];

// ---------------------------------------------------------------------------
// Reference capture
// ---------------------------------------------------------------------------

// Render one screen row the same way MoonTerm's `row_dump` does: every cell in
// the row contributes exactly one character, and the trailing half of a
// double-width character contributes nothing. xterm.js reports a wide tail as
// a zero-width cell, so skipping those keeps the two sides comparable.
function dumpRow(term, y) {
  const line = term.buffer.active.getLine(y);
  if (!line) {
    return ' '.repeat(term.cols);
  }
  let out = '';
  for (let x = 0; x < term.cols; x++) {
    const cell = line.getCell(x);
    if (!cell) {
      out += ' ';
      continue;
    }
    if (cell.getWidth() === 0) {
      continue;
    }
    const chars = cell.getChars();
    out += chars === '' ? ' ' : chars;
  }
  return out;
}

async function capture(entry) {
  const term = new Terminal({
    cols: entry.cols,
    rows: entry.rows,
    allowProposedApi: true,
    scrollback: 0,
  });

  const bytes = Buffer.from(entry.input, 'utf8');
  const writes = [];
  if (entry.splitAt === undefined) {
    writes.push(bytes);
  } else {
    writes.push(bytes.subarray(0, entry.splitAt));
    writes.push(bytes.subarray(entry.splitAt));
  }

  for (const chunk of writes) {
    await new Promise((resolve) => term.write(chunk, resolve));
  }

  const rows = [];
  for (let y = 0; y < entry.rows; y++) {
    rows.push(dumpRow(term, y));
  }

  // Cursor convention. xterm.js stores `cursorX` as the column the *next*
  // character would be written to, so a cursor sitting on the last column of the
  // screen reports `cols`. MoonTerm stores the index of the cell the cursor
  // currently occupies, so the same position reports `cols - 1` together with a
  // pending-wrap flag. The two are the same terminal state described two ways,
  // and the visible screen is identical either way, so the reference value is
  // normalised to MoonTerm's convention before comparison. Without this the
  // cursor assertion would report a difference on every full-width line.
  const cursorX = Math.min(term.buffer.active.cursorX, entry.cols - 1);

  const result = {
    rows,
    cursorX,
    cursorY: term.buffer.active.cursorY,
    alt: term.buffer.active.type === 'alternate',
  };
  term.dispose();
  return result;
}

// ---------------------------------------------------------------------------
// MoonBit emission
// ---------------------------------------------------------------------------

// Escape a screen row for a MoonBit string literal. Anything outside printable
// ASCII becomes a `\u{...}` escape so the generated file stays 7-bit clean and
// cannot be mangled by an editor or a text-mode diff.
function mbString(s) {
  let out = '"';
  for (const ch of s) {
    const cp = ch.codePointAt(0);
    if (ch === '\\') {
      out += '\\\\';
    } else if (ch === '"') {
      out += '\\"';
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else if (ch === '\t') {
      out += '\\t';
    } else if (cp < 0x20 || cp === 0x7f || cp > 0x7e) {
      out += `\\u{${cp.toString(16).toUpperCase()}}`;
    } else {
      out += ch;
    }
  }
  return out + '"';
}

// Encode bytes as a MoonBit `Bytes` literal with explicit hex escapes, so the
// exact byte stream is visible in the source.
function mbBytes(buf) {
  let out = 'b"';
  for (const b of buf) {
    out += `\\x${b.toString(16).toUpperCase().padStart(2, '0')}`;
  }
  return out + '"';
}

async function main() {
  const blocks = [];

  for (const entry of corpus) {
    const expect = await capture(entry);
    const bytes = Buffer.from(entry.input, 'utf8');

    // A split case is fed in two chunks so the parser is exercised across a
    // chunk boundary; both chunks go to the same Terminal.
    let feedLines;
    if (entry.splitAt === undefined) {
      feedLines = [`  t.feed(${mbBytes(bytes)})`];
    } else {
      const head = bytes.subarray(0, entry.splitAt);
      const tail = bytes.subarray(entry.splitAt);
      feedLines = [
        `  t.feed(${mbBytes(head)})`,
        `  t.feed(${mbBytes(tail)})`,
      ];
    }

    const expectedScreen = expect.rows.join('\n');

    blocks.push(
      [
        `///|`,
        `/// ${entry.name}`,
        `///`,
        `/// Reference screen captured from xterm.js @xterm/headless by`,
        `/// \`node tools/oracle.mjs\`. Do not edit by hand.`,
        `test ${mbString(entry.name)} {`,
        `  let t = Terminal::new(${entry.rows}, ${entry.cols})`,
        ...feedLines,
        `  t.finish()`,
        `  assert_eq(t.screen_dump(), ${mbString(expectedScreen)})`,
        `  assert_eq(t.cursor(), (${expect.cursorX}, ${expect.cursorY}))`,
        `  assert_eq(t.is_on_alt(), ${expect.alt})`,
        `}`,
      ].join('\n'),
    );
  }

  const header = [
    `// GENERATED FILE — do not edit.`,
    `//`,
    `// Differential conformance tests: each case feeds a byte stream to MoonTerm`,
    `// and asserts the resulting screen matches what xterm.js produces for the`,
    `// same input. Regenerate with:`,
    `//`,
    `//     node tools/oracle.mjs`,
    `//`,
    `// Source of truth for the corpus is the \`corpus\` array in tools/oracle.mjs.`,
    `// ${corpus.length} cases.`,
    ``,
  ].join('\n');

  writeFileSync(OUT, header + blocks.join('\n\n') + '\n', 'utf8');
  console.log(`wrote ${corpus.length} cases to ${OUT}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
