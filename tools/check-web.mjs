// Smoke-test the JavaScript build of the engine.
//
// The browser demo is driven by generated JavaScript, so a broken binding would
// only show up as a blank page. This script loads the same module the page loads
// and exercises the whole exported surface from Node, which turns "the demo
// works" into something CI can check.
//
// Run `moon build --target js ./web` first, then `node tools/check-web.mjs`.

import * as moonterm from '../_build/js/debug/build/web/web.js';

let failures = 0;

function check(label, actual, expected) {
  const ok = actual === expected;
  if (!ok) {
    failures++;
    console.error(`FAIL ${label}\n  expected: ${JSON.stringify(expected)}\n  actual:   ${JSON.stringify(actual)}`);
  } else {
    console.log(`ok   ${label}`);
  }
}

// Plain text lands in the grid.
moonterm.term_new(3, 20);
moonterm.term_feed_text('hello');
moonterm.term_finish();
check('plain text', moonterm.term_screen_text(), 'hello\n\n');
check('cursor after 5 chars', moonterm.term_cursor(), '5,0');
check('size', moonterm.term_size(), '3,20');

// A split escape sequence is reassembled across two feeds, which is what a
// network stream does in practice.
moonterm.term_new(3, 20);
moonterm.term_feed_text('a\x1b[');
moonterm.term_feed_text('31mRED');
check('split escape sequence', moonterm.term_screen_text(), 'aRED\n\n');

// Styling reaches the HTML renderer.
moonterm.term_new(2, 20);
moonterm.term_feed_text('\x1b[31mred');
const html = moonterm.term_screen_html();
check('html has a colour', html.includes('color:#cd0000;'), true);
check('html has no markup injection', html.includes('<div class="row">'), true);

// Cursor addressing. `CSI 3;5H` is row 3, column 5 in one-based protocol terms,
// so the character lands at zero-based (4, 2) and the cursor then advances one
// column past it.
moonterm.term_new(5, 20);
moonterm.term_feed_text('\x1b[3;5HX');
check('CUP writes at the row', moonterm.term_screen_text().split('\n')[2], '    X');
check('cursor advanced past the written cell', moonterm.term_cursor(), '5,2');

// Wide characters occupy two cells.
moonterm.term_new(3, 10);
moonterm.term_feed_text('中文');
check('wide characters', moonterm.term_screen_text(), '中文\n\n');

// Alternate screen.
moonterm.term_new(3, 20);
moonterm.term_feed_text('main\x1b[?1049halt');
check('alt screen active', moonterm.term_is_alt(), true);
check('alt screen content', moonterm.term_screen_text(), 'alt\n\n');

// Scrollback accumulates lines that scroll off the top.
moonterm.term_new(2, 20);
moonterm.term_feed_text('one\r\ntwo\r\nthree\r\nfour');
check('scrollback length', Number(moonterm.term_scrollback_len()), 2);
check('scrollback content', moonterm.term_scrollback_text(), 'one\ntwo');

// Title from OSC.
moonterm.term_new(3, 20);
moonterm.term_feed_text('\x1b]0;my title\x07');
check('osc title', moonterm.term_title(), 'my title');

// Reset clears everything.
moonterm.term_new(3, 20);
moonterm.term_feed_text('dirty\x1b[5;3Hx\x1bc');
check('reset clears the screen', moonterm.term_screen_text(), '\n\n');

// The ANSI round trip survives the boundary.
moonterm.term_new(2, 20);
moonterm.term_feed_text('\x1b[32mgreen');
const ansi = moonterm.term_ansi();
moonterm.term_new(2, 20);
moonterm.term_feed_text(ansi);
check('ansi round trip through javascript', moonterm.term_screen_text(), 'green\n');

if (failures > 0) {
  console.error(`\n${failures} check(s) failed`);
  process.exit(1);
}
console.log('\nall javascript binding checks passed');
