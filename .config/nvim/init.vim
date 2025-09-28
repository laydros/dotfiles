" init.vim - 2025-09-11 - jwh
" neovim config - migrated from vim .vimrc
" Based on vimrc from 2025-08-27

" Leader
let mapleader = ","             " map leader to comma

" Define config file path for reliable sourcing
let s:config_file = expand('<sfile>:p')

" Bootstrap vim-plug - SIMPLIFIED FOR RELIABILITY
let data_dir = stdpath('data')
let plug_file = data_dir . '/site/autoload/plug.vim'
if empty(glob(plug_file))
  echo "Installing vim-plug..."
  silent execute '!mkdir -p ' . data_dir . '/site/autoload'
  silent execute '!curl -fLo ' . plug_file . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  if v:shell_error == 0
    echo "vim-plug installed successfully. Restarting vim..."
    autocmd VimEnter * PlugInstall --sync | execute 'source' s:config_file
  else
    echo "Failed to install vim-plug. Please install manually."
    finish
  endif
endif

" Auto-install missing plugins
autocmd VimEnter * if exists('g:plugs') && !empty(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | execute 'source' s:config_file
\| endif

" UI
set hidden
set splitbelow splitright
set number relativenumber
set report=0                        " always report # of lines changed for command
set scrolloff=1
set sidescroll=3

" Search
set ignorecase smartcase            " ignore case for searching, unless I specify
set showmatch                       " show matching brackets


" INDENTATION
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
set copyindent
set shiftround                  " round indent to multiple of shiftwidth
set autoindent
set smartindent
set cindent

" Clipboard
set clipboard^=unnamed,unnamedplus  " use system clipboard

" show tabs as "▸·", end-of-line as "↲", and trailing spaces as "·"
set listchars=tab:▸·,trail:·,eol:↲,nbsp:␣
set list

" Load matchit.vim, if a newer version isn't already installed.
if !exists("g:loaded_matchit") && findfile("plugin/matchit.vim", &runtimepath) ==# ""
  runtime! macros/matchit.vim
endif

" number when in insert or focus is lost. relative in command mode
" could instead use Plug 'jeffkreeftmeijer/vim-numbertoggle'
if exists('+relativenumber')
  augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
    autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
  augroup END
endif

autocmd FileType c setlocal noet ts=8 sw=8 tw=80                            " K&R style
autocmd FileType go setlocal noet ts=4 sw=4 nolist                          " Go fmt std
autocmd FileType html setlocal et ts=2 sw=2
autocmd FileType markdown setlocal et ts=2 sw=2 sts=2 spell wrap linebreak
autocmd FileType python setlocal et ts=4 sw=4                               " PEP-8
autocmd FileType go setlocal nolist                " disable whitespace markers for Go

" temporarily disable folding completely
set nofoldenable

" VIM-PLUG
let g:polyglot_disabled = ['markdown']  " Use vim-markdown instead

" Use Neovim's data directory
call plug#begin(stdpath('data') . '/plugged')
Plug 'wellle/context.vim'
Plug 'sheerun/vim-polyglot'
Plug 'preservim/vim-markdown'
Plug 'dense-analysis/ale'    " Linting support
Plug 'simrat39/rust-tools.nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/plenary.nvim'
Plug 'editorconfig/editorconfig-vim'
Plug 'dhruvasagar/vim-table-mode'
" Plug 'jeffkreeftmeijer/vim-dim'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'phanviet/vim-monokai-pro'
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
call plug#end()

" minimal LSP setup
lua << EOF
require'lspconfig'.rust_analyzer.setup{}
EOF

lua << EOF
local rt = require("rust-tools")
rt.setup({
  server = {
    on_attach = function(_, bufnr)
      -- Minimal keybindings
      vim.keymap.set("n", "K", rt.hover_actions.hover_actions, { buffer = bufnr })
      vim.keymap.set("n", "<Leader>a", rt.code_action_groups.code_action_groups, { buffer = bufnr })
    end,
  },
})
EOF

" in theory dim allows the terminals colors to work
" use colorscheme grim for greyscale
# colorscheme dracula
colorscheme monokai_pro

" vim-markdown configuration
let g:vim_markdown_no_default_key_mappings = 1
" let g:vim_markdown_folding_style_pythonic = 1
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_strikethrough = 1
let g:tex_conceal = ""
let g:vim_markdown_math = 1
let g:vim_markdown_frontmatter = 1

" vim-table-mode configuration
let g:table_mode_corner = '|'
let g:table_mode_corner_corner = '|'
let g:table_mode_header_fillchar = '-'

" ALE linter configuration
let g:ale_linters = {'markdown': ['markdownlint']}
let g:ale_fixers = {'markdown': ['trim_whitespace', 'remove_trailing_lines']}
let g:ale_fix_on_save = 1

" Key mappings for markdown
augroup MarkdownMappings
  autocmd!
  autocmd FileType markdown vnoremap <buffer> <leader>b c**<C-r>"**<Esc>       " bold
  autocmd FileType markdown vnoremap <buffer> <leader>i c*<C-r>"*<Esc>         " italic
  autocmd FileType markdown vnoremap <buffer> <leader>s c~~<C-r>"~~<Esc>       " strikethrough
  autocmd FileType markdown vnoremap <buffer> <leader>c c`<C-r>"`<Esc>         " codeblock
  autocmd FileType markdown vnoremap <buffer> <leader>l c[](<C-r>")<Esc>F]i    " insert link
  autocmd FileType markdown nnoremap <buffer> <leader>tm :TableModeToggle<CR>  " table mode toggle
augroup END

" KEYS
inoremap jk <Esc>               " use jk for esc while in insert mode

nnoremap <F5> "=strftime("%Y-%m-%d_%X")<CR>P
inoremap <F5> <C-R>=strftime("%Y-%m-%d_%X")<CR>

