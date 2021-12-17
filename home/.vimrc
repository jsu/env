" Append Settings
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

match Error /\%80v.\+/
set autoindent
set backupdir=~/.vim
set directory=~/.vim
set expandtab
set mouse=c
set shiftwidth=4
set softtabstop=4
set tabstop=4
set timeoutlen=100 ttimeoutlen=10
set undodir=~/.vim
syntax on
