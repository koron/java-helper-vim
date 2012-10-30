" vim:set ts=8 sts=2 sw=2 tw=0 et:
"
" java.vim - Filetype plugin of Java Helper Plugin for Vim.
"
" License: THE VIM LICENSE
"
" Copyright:
"   - (C) 2012 MURAOKA Taro (koron.kaoriya@gmail.com)
"

let g:java_helper_loaded = strftime("%c")

setlocal omnifunc=java_helper#omni_complete

augroup java_helper
  autocmd! * <buffer>
  autocmd CompleteDone <buffer> call java_helper#complete_done()
augroup END
