
" mod navigation, tabs, fast vertical
nnoremap <M-h> :tabprevious<CR>
nnoremap <M-l> :tabnext<CR>
nnoremap <M-j> 10j<CR>
nnoremap <M-k> 10k<CR>
" after make type copen to see errors, navigation hotkeys!
nnoremap <M-left> :cprev<CR>
nnoremap <M-right> :cnext<CR>
" navigate grep lopen window
nnoremap <M-up> :lprev<CR>
nnoremap <M-down> :lnext<CR>


" ctrl navigation, splits
nnoremap <C-h> <C-w><C-h>
nnoremap <C-j> <C-w><C-j>
nnoremap <C-k> <C-w><C-k>
nnoremap <C-l> <C-w><C-l>


" highlight trailing whitespace in insert mode
highlight ExtraWhitespace ctermbg=red guibg=red
autocmd InsertEnter * match ExtraWhitespace /\s\+$/
autocmd InsertLeave * call clearmatches()


" color adjustments
highlight TabLineFill 	ctermfg=black
highlight TabLine 	ctermbg=black	ctermfg=cyan
highlight TabLineSel 	ctermbg=black	ctermfg=white
highlight StatusLine 	ctermbg=white 	ctermfg=black
highlight StatusLineNC 	ctermbg=cyan 	ctermfg=black
highlight VertSplit 	ctermbg=black 	ctermfg=black
