// Keep README.md in step with README.mbt.md.
//
// README.mbt.md is the source of truth. It is the file MoonBit compiles, so the
// `mbt check` block in it is run by `moon test` and the documented usage cannot
// drift away from the real API. GitHub, however, only renders README.md.
//
// Rather than keeping two copies that quietly diverge, this script copies one to
// the other, and CI runs it with `--check` to fail the build if they differ.
//
//     node tools/sync-readme.mjs           # write README.md
//     node tools/sync-readme.mjs --check    # verify they match

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = join(HERE, '..', 'README.mbt.md');
const DST = join(HERE, '..', 'README.md');

// A one-line banner so a reader who lands on README.md knows which file to edit.
const BANNER = '<!-- Generated from README.mbt.md by tools/sync-readme.mjs — edit that file, not this one. -->\n\n';

const source = readFileSync(SRC, 'utf8');
const expected = BANNER + source;

if (process.argv.includes('--check')) {
  let actual = '';
  try {
    actual = readFileSync(DST, 'utf8');
  } catch {
    console.error('README.md is missing; run: node tools/sync-readme.mjs');
    process.exit(1);
  }
  if (actual !== expected) {
    console.error('README.md is out of date; run: node tools/sync-readme.mjs');
    process.exit(1);
  }
  console.log('README.md is in sync with README.mbt.md');
} else {
  writeFileSync(DST, expected, 'utf8');
  console.log('wrote README.md from README.mbt.md');
}
