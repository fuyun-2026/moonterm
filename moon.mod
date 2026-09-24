// Module metadata. See
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// `name` must be `<owner>/<module>` where `<owner>` is the mooncakes.io account
// that will publish it. The owner below is also the GitHub account, which keeps
// the registry entry and the repository pointing at the same place. Renaming it
// means updating the `import` lines in `moon.pkg`, `term/moon.pkg`,
// `render/moon.pkg`, `web/moon.pkg` and `cmd/main/moon.pkg` to match.

name = "fuyun-2026/moonterm"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/fuyun-2026/moonterm"

license = "Apache-2.0"

keywords = [
  "terminal",
  "vt100",
  "ansi",
  "escape-sequences",
  "emulator",
  "ecma-48",
  "tui",
]

// `wasm-gc` rather than plain `wasm`: the engine allocates, and the GC target
// gives it a managed heap without pulling in a bundled allocator. The `js`
// backend is the one the browser demo uses, and `native` is what makes the test
// suite fast.

preferred_target = "wasm-gc"

description = "A terminal emulator core: parses ANSI/VT escape sequences and maintains the screen they describe, verified against xterm.js."
