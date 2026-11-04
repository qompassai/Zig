# Changelog — qompassai/zig-template

## 2026-09-28 — Initial template

- Created as a GitHub **template repository** (`is_template=true`, public) for Zig projects.
- Standard layout: `src/`, `tests/`, `docs/`, `examples/`, `.github/workflows/ci.yml` sanity job.
- Starter: hello-world in Zig (`src/00_hello.zig` + runnable copy in `examples/`).
- `README.md` ships with `{{PROJECT}}` / `{{DESCRIPTION}}` / `{{SLUG}}` placeholders and a "How to use this template" section (deleted on instantiation).
- License: Apache 2.0 only (`LICENSE`, `Copyright 2026 Qompass AI`); `CITATION.cff` declares SPDX `Apache-2.0`.
- Neovim-first: `.nvim.lua` project-local config (defines commands only, never auto-executes), `docs/NEOVIM.md` diver wiring guide, `.editorconfig`.
- Tiger style: explicit contracts, one idea per file, ELI5 comments where the subject is surprising.
