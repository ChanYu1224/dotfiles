" Ward off unexpected things that your distro might have made, as
" well as sanely reset options when re-sourcing .vimrc
set nocompatible

" Set Dein base path (required)
let s:dein_base = '$HOME/.cache/dein'

" Set Dein source path (required)
let s:dein_src = '$HOME/.cache/dein/repos/github.com/Shougo/dein.vim'

" Set Dein runtime path (required)
execute 'set runtimepath+=' . s:dein_src

" Call Dein initialization (required)
call dein#begin(s:dein_base)

call dein#add(s:dein_src)

" Your plugins go here:
"call dein#add('Shougo/neosnippet.vim')
"call dein#add('Shougo/neosnippet-snippets')

" Finish Dein initialization (required)
call dein#end()

" Attempt to determine the type of a file based on its name and possibly its
" contents. Use this to allow intelligent auto-indenting for each filetype,
" and for plugins that are filetype specific.
if has('filetype')
  filetype indent plugin on
endif

" Enable syntax highlighting
if has('syntax')
  syntax on
endif

" Uncomment if you want to install not-installed plugins on startup.
"if dein#check_install()
" call dein#install()
"endif

if &compatible
  set nocompatible
endif
set runtimepath+=~/.cache/dein/repos/github.com/Shougo/dein.vim
if dein#load_state('~/.cache/dein')
  call dein#begin('~/.cache/dein')
  call dein#load_toml('~/.config/nvim/dein.toml', {'lazy': 0})
  call dein#load_toml('~/.config/nvim/dein_lazy.toml', {'lazy': 1})
  call dein#end()
  call dein#save_state()
endif

if dein#check_install()
	call dein#install()
endif

filetype plugin indent on

let g:python3_host_prog = $PYENV_ROOT.'/versions/neovim/bin/python'

" ---------------------------------------------
" configuration of additional functions
" ---------------------------------------------

" enable mouse control
set mouse=a

" enable syntax highlight
syntax enable

" enable wildmenu (able to select file)
set wildmenu

" remove appearance of duplicated charactors
set ambiwidth=double

" keep the indent of previous line
set smartindent

" highlight matching simbols
set showmatch

" preserve results of yank into clipboard
set clipboard+=unnamed

" keep history of commands
set history=1000

set ttimeoutlen=50

" -----------------------------------------------
" configurations of displaying information
" -----------------------------------------------

" display line number 
set number

" display title
set title

" display input command
set showcmd

" display cursor position at right down 
set ruler

" display 2 lines status bar
set laststatus=2

" ---------------------
" configurations of tab
" ---------------------

set shiftwidth=0
set softtabstop=4
set tabstop=4

" ---------------------------
" configurations of searching
" ---------------------------

set hlsearch
set incsearch
set wrapscan

" -----------------------------
" configurations of colorscheme
" -----------------------------
colorscheme monokai
