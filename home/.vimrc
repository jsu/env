" Append Settings
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

set backupdir=~/.vim/tmp
set directory=~/.vim/tmp
set undodir=~/.vim/tmp
set mouse=c
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
set autoindent
syntax on

set timeoutlen=100 ttimeoutlen=10
inoremap jk <esc>
nnoremap jk <esc>
nnoremap jk :noh<return><esc>
nnoremap jk^[ <esc>^[
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[
match Error /\%80v.\+/
