


" Append Settings
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

set autoindent
set backupdir=~/.vim
set directory=~/.vim
set expandtab
set mouse=c
set ruler
set shiftwidth=4
set softtabstop=4
set tabstop=4
set timeoutlen=100 ttimeoutlen=10
set undodir=~/.vim
syntax on

augroup vimrc_autocmds
  autocmd BufEnter * highlight OverLength ctermbg=darkgrey guibg=#111111
  autocmd BufEnter * match OverLength /\%75v.*/
augroup END
