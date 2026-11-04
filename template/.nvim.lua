-- .nvim.lua — project-local Neovim configuration for Zig projects.
--
-- This file is read by Neovim when you open this project directory IF you
-- have 'exrc' enabled (:help 'exrc'). It NEVER shells out on its own: it
-- only defines user commands and buffer-local settings. Nothing runs until
-- you run it.
--
-- SECURITY: review before trusting — especially in repos you did not author.
-- Matt drives his projects from his own Neovim config (diver); see
-- docs/NEOVIM.md for how this template expects diver to be wired.

if vim == nil then return end -- not in Neovim (e.g. luac syntax check)

-- Buffer-local sanity defaults. Adjust per project.
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.expandtab = true

-- :TemplateInfo — remind yourself how this template plugs into diver.
vim.api.nvim_create_user_command('TemplateInfo', function()
  vim.notify(
    'Zig template: wire formatter/linter/DAP in diver, then read docs/NEOVIM.md.',
    vim.log.levels.INFO
  )
end, { desc = 'Show Zig template editor wiring notes' })

-- Stubs: point these at your real diver-wired tools. They stay no-ops
-- until you configure them, so a fresh clone can never format or lint
-- with the wrong tool by accident.
vim.api.nvim_create_user_command('TemplateFormat', function()
  vim.notify(
    'TemplateFormat: configure your formatter in diver first (docs/NEOVIM.md).',
    vim.log.levels.WARN
  )
end, { desc = 'Format via your configured formatter (stub)' })

vim.api.nvim_create_user_command('TemplateLint', function()
  vim.notify(
    'TemplateLint: configure your linter in diver first (docs/NEOVIM.md).',
    vim.log.levels.WARN
  )
end, { desc = 'Lint via your configured linter (stub)' })
