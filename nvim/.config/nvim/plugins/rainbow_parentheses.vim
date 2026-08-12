let g:rainbow#max_level = 16
let g:rainbow#pairs = [['(', ')'], ['[', ']']]

augroup rainbow_lisp
  autocmd!
  autocmd FileType lisp,clojure,scheme RainbowParentheses
augroup END
