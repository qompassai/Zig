# Driving this project from Neovim (diver)

Matt builds in Neovim; his config (**diver**) is the primary build driver
for every project started from this template. This page is the wiring
checklist. Nothing here installs editor plugins for you — diver owns the
tooling, the project only declares what it needs.

## 1. Trust the local config

This repo ships `.nvim.lua` (project-local settings + `:TemplateInfo`,
`:TemplateFormat`, `:TemplateLint` command stubs). It defines commands
only; it never runs shell commands by itself. To let Neovim read it:

```vim
:set exrc
```

Read `.nvim.lua` once before enabling — never enable `exrc` blindly on
repos you did not author.

## 2. Formatting

- Set `shiftwidth`/`tabstop` per `.editorconfig` (diver reads it).
- `:TemplateFormat` is a stub: point it at the formatter diver already
  wires for this language (e.g. the project's formatter entry in
  diver's formatter catalog), or just use diver's format keymap.

## 3. Linting

- `:TemplateLint` is a stub for the same reason. Wire it to the linter
  you use for Zig in diver (or nvim-lint / native tooling).

## 4. Build, test, run

- Prefer `:make` / `:terminal` over leaving the editor. Keep commands in
  `docs/TOOLCHAIN.md` so any checkout documents the exact invocations.
- CI (`.github/workflows/ci.yml`) runs the same sanity checks remotely.

## 5. Debugging

- If this language has a DAP adapter in diver's `lua/dap/` registry, use
  it. Otherwise add the adapter config there first, then debug from
  inside Neovim — no external IDE required.

## 6. Tasks

- Project tasks belong in version control (a `Justfile`, `Taskfile.yml`,
  or plain shell scripts under `scripts/`), never only in someone's
  shell history.
