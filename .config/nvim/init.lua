-- init.lua - 2025-10-29 - jwh
-- Modern Neovim configuration using lazy.nvim and built-in LSP

-- Leader keys - set before lazy.nvim
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Basic Settings
local opt = vim.opt

-- UI
opt.hidden = true
opt.termguicolors = true
opt.cursorline = false
opt.splitbelow = true
opt.splitright = true
opt.number = true
opt.relativenumber = true
opt.report = 0
opt.ruler = true
opt.scrolloff = 1
opt.sidescroll = 3

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true
opt.showmatch = true

-- Indentation
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.expandtab = true
opt.copyindent = true
opt.shiftround = true
opt.autoindent = true
opt.smartindent = true
opt.cindent = true

-- Clipboard
opt.clipboard:prepend({ "unnamed", "unnamedplus" })

-- Whitespace visualization
opt.listchars = { tab = '▸·', trail = '·', eol = '↲', nbsp = '␣' }
opt.list = true

-- Disable folding completely
opt.foldenable = false

-- Load matchit.vim if not already loaded
if vim.fn.exists("g:loaded_matchit") == 0 and vim.fn.findfile("plugin/matchit.vim", vim.o.runtimepath) ~= "" then
  vim.cmd("runtime! macros/matchit.vim")
end

-- Plugin configurations (must be set before lazy.nvim loads plugins)
vim.g.polyglot_disabled = { 'markdown' }

-- Number toggle: relative in command mode, absolute in insert or when focus lost
local numbertoggle_group = vim.api.nvim_create_augroup("numbertoggle", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = numbertoggle_group,
  callback = function()
    if vim.wo.number and vim.fn.mode() ~= "i" then
      vim.wo.relativenumber = true
    end
  end
})
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  group = numbertoggle_group,
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end
})

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- File-type specific settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "c",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
    vim.bo.textwidth = 80
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.wo.list = false
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "html",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.wo.spell = true
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.colorcolumn = "80"
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end
})

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },  -- Import all plugin specs from lua/plugins/
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
})

-- Colorscheme
vim.cmd('colorscheme monokai_soda')

-- ALE linter configuration
vim.g.ale_linters = { markdown = { 'markdownlint' } }
vim.g.ale_fixers = { markdown = { 'trim_whitespace', 'remove_trailing_lines' } }
vim.g.ale_fix_on_save = 1

-- Markdown keymaps
local markdown_group = vim.api.nvim_create_augroup("MarkdownMappings", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = markdown_group,
  pattern = "markdown",
  callback = function()
    local opts = { buffer = true, noremap = true }
    vim.keymap.set('v', '<leader>b', 'c**<C-r>"**<Esc>', opts)  -- bold
    vim.keymap.set('v', '<leader>i', 'c*<C-r>"*<Esc>', opts)    -- italic
    vim.keymap.set('v', '<leader>s', 'c~~<C-r>"~~<Esc>', opts)  -- strikethrough
    vim.keymap.set('v', '<leader>c', 'c`<C-r>"`<Esc>', opts)    -- code
    vim.keymap.set('v', '<leader>l', 'c[](<C-r>")<Esc>F]i', opts)  -- link
    vim.keymap.set('n', '<leader>tm', ':TableModeToggle<CR>', opts)  -- table mode
  end
})

-- Key mappings
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true })  -- jk for escape

-- Date insertion
vim.keymap.set('n', '<F5>', '"=strftime("%Y-%m-%d_%X")<CR>P', { noremap = true })
vim.keymap.set('i', '<F5>', '<C-R>=strftime("%Y-%m-%d_%X")<CR>', { noremap = true })
