-- init.lua -- 2025-09-24 - jwh
-- Neovim configuration file

-- Leader
vim.g.mapleader = ","

-- auto install vim-plug and plugins, if not found
local data_dir = vim.fn.stdpath('data')
if vim.fn.empty(vim.fn.glob(data_dir .. '/site/autoload/plug.vim')) == 1 then
    vim.cmd('silent !curl -fLo ' .. data_dir .. '/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
    vim.o.runtimepath = vim.o.runtimepath
    vim.cmd('autocmd VimEnter * PlugInstall --sync | source $MYVIMRC')
end

local vim = vim
local Plug = vim.fn['plug#']

vim.call('plug#begin')

Plug('sheerun/vim-polyglot')
Plug('editorconfig/editorconfig-vim')
Plug('nvim-lualine/lualine.nvim') -- statusline
Plug('nvim-tree/nvim-web-devicons') -- fancy icons
Plug('folke/which-key.nvim') -- mappings popup
Plug('romgrk/barbar.nvim') -- bufferline
Plug('goolord/alpha-nvim') -- fancy startup



vim.call('plug#end')


-- Basic
local o = vim.opt

-- UI
o.hidden         = true
o.termguicolors  = true    -- truecolor for modern terminals
o.cursorline     = false
o.splitbelow, o.splitright = true, true
o.number, o.relativenumber = true, true
o.report         = 0
o.ruler          = true
o.scrolloff	     = 1


-- Search
o.ignorecase, o.smartcase  = true, true
o.hlsearch   = false
o.incsearch  = true
o.showmatch  = true

-- Indentation
o.shiftwidth   = 4
o.tabstop      = 4
o.softtabstop  = 4
o.expandtab    = true
o.copyindent   = true
o.shiftround   = true
o.autoindent   = true
o.smartindent  = true

-- Clipboard
o.clipboard:prepend({ "unnamed", "unnamedplus" })

