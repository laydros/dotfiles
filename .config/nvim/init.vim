" init.vim - 2025-09-11 - jwh
" neovim config - migrated from vim .vimrc
" Based on vimrc from 2025-08-27

" Define config file path for reliable sourcing
let s:config_file = expand('<sfile>:p')

" Bootstrap vim-plug - SIMPLIFIED FOR RELIABILITY
let data_dir = stdpath('data')

" Install vim-plug if not present
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

" Always use the system clipboard (requires vim compiled with +clipboard)
if has('clipboard')
  set clipboard^=unnamed,unnamedplus
endif

" show tabs as "▸·", end-of-line as "↲", and trailing spaces as "·"
set listchars=tab:▸·,trail:·,eol:↲,nbsp:␣
set list
set modelines=5                 " number of lines to check for modeline
set nrformats=hex,bin           " what number formats to consider when using C-A C-X
set sessionoptions-=options     " for :mksession command
set tabpagemax=50
set tags=./tags;,tags

" hoping to fix ghostty garbles in vim
set lazyredraw
set termguicolors
set t_ut=          " disable background color erase

" Load matchit.vim, if a newer version isn't already installed.
if !exists("g:loaded_matchit") && findfile("plugin/matchit.vim", &runtimepath) ==# ""
  runtime! macros/matchit.vim
endif

"
" start my options
set hidden                      " abandon hidden buffers

" save undo-trees in files (using XDG paths)
if has('persistent_undo')
  set undofile
  let &undodir = stdpath('state') . '/undo'
  if !isdirectory(&undodir)
    call mkdir(&undodir, "p", 0700)
  endif
  set undolevels=10000
  set undoreload=10000
endif

" seems to cause issue with abbrv starting with _
"set iskeyword-=_                " treat '_' as word separator

" UI
set report=0                    " always report # of lines changed for command
set ruler
set scrolloff=1
set sidescroll=3
set splitbelow
set splitright
set showmode
set showmatch                   " show matching brackets
set showcmd

" LINE NUMBERING
set number
"set relativenumber

" number when in insert or focus is lost. relative in command mode
" could instead use Plug 'jeffkreeftmeijer/vim-numbertoggle'
if exists('+relativenumber')
  augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
    autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
  augroup END
endif

" INDENTATION
set smartindent
set softtabstop=4
set shiftwidth=4
set tabstop=4
set shiftround                  " round indent to multiple of shiftwidth
set copyindent
set expandtab
set cindent

autocmd FileType c setlocal noet ts=8 sw=8 tw=80
autocmd FileType go setlocal noet ts=4 sw=4
autocmd FileType html setlocal et ts=2 sw=2
autocmd FileType markdown setlocal et ts=2 sw=2 tw=80
autocmd FileType python setlocal et ts=4 sw=4

autocmd FileType go setlocal nolist  " disable whitespace markers for Go

" Basic Go support (built into vim 8+)
autocmd BufRead,BufNewFile *.go set filetype=go

" MARKDOWN FOLDING
" let g:markdown_folding = 1

" temporarily disable folding completely
set nofoldenable

" VIM-PLUG
" Use Neovim's data directory
call plug#begin(stdpath('data') . '/plugged')
Plug 'wellle/context.vim'
Plug 'sheerun/vim-polyglot'
Plug 'preservim/vim-markdown'
Plug 'dense-analysis/ale'    " Linting support
Plug 'dhruvasagar/vim-table-mode'
Plug 'jeffkreeftmeijer/vim-dim'
Plug 'jkramer/vim-checkbox'
Plug 'dracula/vim', { 'as': 'dracula' }
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
call plug#end()

" colorscheme nord
" in theory dim allows the terminals colors to work
" use colorscheme grim for greyscale

" colorscheme dim
colorscheme dracula

" case search
set ignorecase                  " ignore case for searching
set smartcase                   " but look for case if I search with it

" ensure xterm-256color
if &term =~ '256color'
  set t_Co=256
endif

" vim-markdown configuration
let g:vim_markdown_no_default_key_mappings = 1
let g:vim_markdown_folding_style_pythonic = 1
let g:vim_markdown_folding_disabled = 0
let g:vim_markdown_strikethrough = 1
let g:tex_conceal = ""
let g:vim_markdown_math = 1
let g:vim_markdown_frontmatter = 1

" vim-table-mode configuration
let g:table_mode_corner = '|'
let g:table_mode_corner_corner = '|'
let g:table_mode_header_fillchar = '-'

" ALE linter configuration
let g:ale_linters = {
\   'markdown': ['markdownlint'],
\}
let g:ale_fixers = {
\   'markdown': ['trim_whitespace', 'remove_trailing_lines'],
\}
let g:ale_fix_on_save = 1


" Markdown-specific settings
augroup MarkdownSettings
  autocmd!
  autocmd FileType markdown setlocal shiftwidth=2
  autocmd FileType markdown setlocal tabstop=2
  autocmd FileType markdown setlocal softtabstop=2
  autocmd FileType markdown setlocal expandtab
  autocmd FileType markdown setlocal wrap
  autocmd FileType markdown setlocal linebreak
  autocmd FileType markdown setlocal spell
  autocmd FileType markdown setlocal spelllang=en_us
  autocmd FileType markdown setlocal textwidth=0
  autocmd FileType markdown setlocal wrapmargin=0
augroup END

" Key mappings for markdown
augroup MarkdownMappings
  autocmd!
  " Bold and italic in visual mode
  autocmd FileType markdown vnoremap <buffer> <leader>b c**<C-r>"**<Esc>
  autocmd FileType markdown vnoremap <buffer> <leader>i c*<C-r>"*<Esc>
  
  " Strikethrough
  autocmd FileType markdown vnoremap <buffer> <leader>s c~~<C-r>"~~<Esc>
  
  " Code block
  autocmd FileType markdown vnoremap <buffer> <leader>c c`<C-r>"`<Esc>
  
  " Insert link
  autocmd FileType markdown vnoremap <buffer> <leader>l c[](<C-r>")<Esc>F]i
  
  " Table mode toggle
  autocmd FileType markdown nnoremap <buffer> <leader>tm :TableModeToggle<CR>
augroup END

" Additional markdown helpers
function! MarkdownLevel()
  if getline(v:lnum) =~ '^# .*$'
    return ">1"
  endif
  if getline(v:lnum) =~ '^## .*$'
    return ">2"
  endif
  if getline(v:lnum) =~ '^### .*$'
    return ">3"
  endif
  if getline(v:lnum) =~ '^#### .*$'
    return ">4"
  endif
  if getline(v:lnum) =~ '^##### .*$'
    return ">5"
  endif
  if getline(v:lnum) =~ '^###### .*$'
    return ">6"
  endif
  return "="
endfunction

augroup MarkdownFolding
  autocmd!
  autocmd FileType markdown setlocal foldexpr=MarkdownLevel()  
  autocmd FileType markdown setlocal foldmethod=expr
augroup END


" KEYS
inoremap jk <Esc>               " use jk for esc while in insert mode
let mapleader = ","             " map leader to comma

nnoremap <F5> "=strftime("%Y-%m-%d_%X")<CR>P
inoremap <F5> <C-R>=strftime("%Y-%m-%d_%X")<CR>
iab <expr> sdate strftime("%Y-%m-%d_%X")

" ABBREVIATIONS
abbr _lia <li><a href=""></a></li>

" FUNCTIONS
" to insert md code block. need to setup keymap
function! s:CodeSnippet(...)
  let out = '```'
  if a:0 == 1
    let out = out . a:1
  endif
  "      ↓ makes it easier to %s OPENING set of code fences
  put = ' '.out
  "   ↓ outputs clipboard
  put +
  put ='```'
endfunction

" it's a .vimrc file that makes you look like a ninja. it's the absolute
" minimal setup. no colors, no highlights, no messages, no status bar,
" nothing. just text.

"ninja vimrc http://xero.nu
"set nocompatible
"set modelines=0
"set shortmess+=I
"set noshowmode
"set noshowcmd
"set hidden
"set lazyredraw
"set noruler
"set laststatus=0
"syntax off
"filetype off