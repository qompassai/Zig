<!-- qompassai/zig-template/README.md -->
<!-- Replace Zig, Template for Qompass AI Zig projects. and zig when you instantiate this template. -->

# Zig

> Template for Qompass AI Zig projects.

<a href="./LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"></a>

A Qompass AI template for Zig (language) projects — educational
content, tooling notes, and starter code in the standard Qompass AI layout.

## How to use this template

This template now lives in the Zig language repository at
https://github.com/qompassai/Zig/tree/main/template. Start a new project
from it with a sparse checkout:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/qompassai/Zig.git <project>
git -C <project> sparse-checkout set template
cp -a <project>/template/. <project>/
rm -rf <project>/template
```

Then replace every `{{PLACEHOLDER}}` in this README and in
`CITATION.cff`, delete this section, and start from `src/00_hello.*` — it
runs with the stock toolchain, no extra setup.

Placeholders used in this template:

| Placeholder      | Meaning                          | Example               |
|------------------|----------------------------------|-----------------------|
| `Zig`    | Project name, title case         | Zig           |
| `Template for Qompass AI Zig projects.`| One-line repo description        | Template for Qompass AI Zig projects.       |
| `zig`       | Lowercase, URL-safe name         | zig              |

## Layout

```text
src/            # teaching material: tutorials, annotated examples
tests/          # exercises with expected outputs (validation, not vibes)
docs/           # deep dives: setup, idioms, gotchas, ecosystem map
examples/       # runnable snippets, smallest-first
.github/        # CI: sanity checks on every push
```

## Neovim-first

Matt builds in Neovim. His config (diver) is the primary driver here:
see [docs/NEOVIM.md](docs/NEOVIM.md) for the wiring checklist
(formatter, linter, build/test, DAP). `.nvim.lua` ships project-local
settings — it defines commands only and never runs anything by itself.

## License

This project is licensed under the [Apache License, Version 2.0](./LICENSE).

Copyright 2026 Qompass AI.
