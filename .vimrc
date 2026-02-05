" Minimal .vimrc — sensible defaults for standalone vim

" General
set nocompatible
set encoding=utf-8
set hidden
set autoread
set backspace=indent,eol,start

" UI
set number
set relativenumber
set cursorline
set showcmd
set showmode
set laststatus=2
set ruler
set wildmenu
set wildmode=longest:full,full
set scrolloff=8
set signcolumn=yes

" Search
set incsearch
set hlsearch
set ignorecase
set smartcase

" Indentation
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" Splits
set splitbelow
set splitright

" Split navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Escape with jk (matches nvim config)
inoremap jk <Esc>

" Syntax
syntax enable
filetype plugin indent on

" Disable swap/backup (use persistent undo instead)
set noswapfile
set nobackup
set nowritebackup
set undofile
set undodir=~/.vim/undodir

" Status line
set statusline=%f\ %m%r%h%w\ %=%l/%L\ col\ %c\ %p%%

" Colors
set termguicolors
set background=dark
