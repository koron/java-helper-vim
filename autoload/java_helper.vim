" vim:set ts=8 sts=2 sw=2 tw=0 et nowrap:
"
" java_helper.vim - Autoload plugin of Java Helper Plugin for Vim.
"
" License: THE VIM LICENSE
"
" Copyright:
"   - (C) 2012 MURAOKA Taro (koron.kaoriya@gmail.com)
"

scriptencoding utf-8

let s:revision = 1
let s:classes = {}
if !exists('s:db')
  let s:db = []
endif

"###########################################################################

" regulate path (convert Windows style to UNIX style if needs)
function! java_helper#_regulate_path(path)
  if &shellslash
    return substitute(a:path, '\\', '/', 'g')
  else
    return a:path
  endif
endfunction

" extract package name from full class name.
function! java_helper#_package_name(full_name)
  if a:full_name =~# '\.'
    return substitute(a:full_name, '\.[^.]*$', '', '')
  else
    return '<no package>'
  endif
endfunction

" get simple name from full class name.
function! java_helper#_simple_name(class)
  return matchstr(a:class, '[^.]\+$')
endfunction

" add an entry to "short to full class name" table (1xM mapping).
function! java_helper#_add(dict, short_name, full_name)
  if a:short_name ==# ''
    return
  endif
  let names = get(a:dict, a:short_name, [])
  if len(names) == 0
    let a:dict[a:short_name] = names
  endif
  if index(names, a:full_name) == -1
    call add(names, a:full_name)
  endif
endfunction

" get weight (significance) of class
function! java_helper#_get_weight(name)
  if a:name =~# '\M^java.awt.' | return 120 | endif
  if a:name =~# '\M^javax.' | return 110 | endif
  if a:name =~# '\M^java.lang.' | return 100 | endif
  if a:name =~# '\M^java.io.' | return 101 | endif
  if a:name =~# '\M^java.util.' | return 102 | endif
  if a:name =~# '\M^java.net.' | return 103 | endif
  if a:name =~# '\M^java.' | return 109 | endif
  if a:name =~# '\M^android.' | return 200 | endif
  if a:name =~# '\M^com.\(sun\|oracle\).' | return 900 | endif
  if a:name =~# '\M^sunw.' | return 900 | endif
  if a:name =~# '\M^sun.' | return 900 | endif
  return 499
endfunction

" compare classes by its significance for user.
function! java_helper#_compare_class(item1, item2)
  return java_helper#_get_weight(a:item1) - java_helper#_get_weight(a:item2)
endfunction

" compare two strings.
function! java_helper#_strcmp(str1, str2)
  if a:str1 <# a:str2
    return -1
  elseif a:str1 ==# a:str2
    return 0
  else
    return 1
  endif
endfunction

"###########################################################################

function! java_helper#revision()
  return s:revision
endfunction

function! java_helper#is_android()
  " TODO:
  return 1
endfunction

" find jar file, return its full path.
function! java_helper#find_jarfile(name)
  let path = java_helper#_regulate_path($JAVA_HOME) . '/jre/lib/' . a:name
  if filereadable(path)
    return path
  else
    return ''
  end
endfunction

" list up valid jar files for current buffer and its project.
function! java_helper#list_jarfiles()
  let jars = []
  if java_helper#is_android()
    " TODO:
    let sdkdir = java_helper#_regulate_path($ANDROID_SDK)
    call add(jars, sdkdir . '/platforms/android-16/android.jar')
  else
    call add(jars, java_helper#find_jarfile('rt.jar'))
  endif
  return jars
endfunction

" reset database.
function! java_helper#reset_db()
  let s:db = []
endfunction

function! java_helper#setup_db(force)
  if !a:force && len(s:db) != 0
    return s:db
  endif
  let jars = java_helper#list_jarfiles()
  if len(jars) <= 0
    return []
  else
    let s:db = java_helper#db_load(jars[0])
    return s:db
  endif
endfunction

"###########################################################################
" OMNI COMPLETION

function! java_helper#omni_complete(findstart, base)
  if a:findstart
    return java_helper#omni_pre_search()
  else
    return java_helper#omni_search2(a:base)
  endif
endfunction

function! java_helper#omni_pre_search()
  let lstr = getline('.')
  let cnum = col('.')
  let idx = match(lstr, '\k\+\%' . cnum . 'c')
  if idx >= 0
    let b:java_helper_last_omnibase = idx
    return idx
  else
    return -1
  endif
endfunction

function! java_helper#omni_search2(base)
  if len(a:base) == 0
    return []
  endif
  let db = java_helper#setup_db(0)
  let items = java_helper#db_select_class(db, a:base)
  let words = java_helper#omni_format(items, a:base)
  call sort(words, 'java_helper#compare_items')
  let b:java_helper_last_omniwords = words
  return { 'words': words }
endfunction

function! java_helper#omni_format(items, base)
  call filter(a:items, 'java_helper#omni_format_filter(v:val)')
  return map(a:items, 'java_helper#omni_format_item(v:val, a:base)')
endfunction

function! java_helper#omni_format_filter(item)
  return a:item['pweight'] < 500
endfunction

function! java_helper#get_item_weight(item, base)
  let order = a:item['pweight']
  let name = a:item['sname']
  if name ==# a:base
    let order += 1000
  elseif name ==? a:base
    let order += 2000
  else
    let idx = stridx(name, a:base)
    if idx == 0 || idx == len(name) - len(a:base)
      let order += 3000
    else
      let order += 9000
    endif
  endif
  return order
endfunction

function! java_helper#omni_format_item(item, base)
  let order = java_helper#get_item_weight(a:item, a:base)
  return {
        \ 'word': a:item['fname'],
        \ 'abbr': a:item['sname'],
        \ 'menu': a:item['pname'],
        \ '_order': order
        \ }
endfunction

function! java_helper#compare_items(item1, item2)
  let diff = a:item1['_order'] - a:item2['_order']
  if diff != 0
    return diff
  endif
  let diff = java_helper#_strcmp(a:item1['menu'], a:item2['menu'])
  if diff != 0
    return diff
  endif
  let diff = java_helper#_strcmp(a:item1['abbr'], a:item2['abbr'])
  if diff != 0
    return diff
  endif
  let diff = java_helper#_strcmp(a:item1['word'], a:item2['word'])
  return diff
endfunction

" CompleteDone handler.
function! java_helper#complete_done()
  call java_helper#finish_complete()
endfunction

" add import statement if can, replace to short name.
function! java_helper#finish_complete()
  if !exists('b:java_helper_last_omnibase') ||
        \ !exists('b:java_helper_last_omniwords')
    return
  endif
  let line = getline('.')
  let start = b:java_helper_last_omnibase
  let end = col('.')
  let selected = line[start : end]

  if java_helper#add_import(selected)
    let prev = start > 0 ? line[0 : start - 1] : ''
    let short = java_helper#_simple_name(selected)
    call setline('.', prev . short . line[end : ])
  endif

  unlet b:java_helper_last_omnibase
  unlet b:java_helper_last_omniwords
endfunction

"###########################################################################
" IMPORT OPERATIONS

function! java_helper#get_imports_range()
  let save_pos = getpos('.')
  try
    normal! gg
    let start = search('\m^import .*;', 'cW')
    if start == 0
      return []
    endif
    normal! G
    let end = search('\m^import .*;', 'bcW')
    if end == 0
      return [start, start]
    endif
    return [start, end]
  finally
    call setpos('.', save_pos)
  endtry
endfunction

" scan import which match full class name.
" 0:found, 1:not, 2:cant
function! java_helper#scan_import(full_name, start, end)
  let short_name = java_helper#_simple_name(a:full_name)
  let lines = getline(a:start, a:end)
  for line in lines
    let full = matchstr(line, '\m^import\s\+\zs.\+\ze;')
    let short = java_helper#_simple_name(full)
    if full ==# a:full_name
      return 0
    elseif short ==# short_name
      return 2
    endif
  endfor
  return 1
endfunction

function! java_helper#get_import_line(full_name, range)
  if len(a:range) < 2
    " consider package statement
    if getline(1) =~# '\m^package\s'
      if getline(2) =~# '\m^\s*$'
        return 2
      else
        return 1
      endif
    endif
    return 0
  else
    " TODO: consider import block.
    return a:range[1]
  endif
endfunction

function! java_helper#add_import(full_name)
  let range = java_helper#get_imports_range()
  " detect existing import statement.
  if len(range) == 2
    let retval = java_helper#scan_import(a:full_name, range[0], range[1])
    if retval == 0
      return 1
    elseif retval == 2
      return 0
    endif
  endif
  " insert an import statement.
  let pos = java_helper#get_import_line(a:full_name, range)
  call append(pos, 'import '.a:full_name.';')
  return 1
endfunction

"###########################################################################
" DB

function! java_helper#db_load_jar(jarfile)
  if a:jarfile ==# '' || !filereadable(a:jarfile)
    return []
  endif
  let classes = split(system('jar -tf ' . a:jarfile), '\n')
  call filter(classes, 'java_helper#db_load_jar_filter(v:val)')
  call map(classes, 'java_helper#db_load_jar_map(v:val)')
  return classes
endfunction

function! java_helper#db_load_jar_filter(entry)
  return a:entry =~# '\m\.class$' && a:entry !~# '\m\$\d\+\.class$'
endfunction

function! java_helper#db_load_jar_map(entry)
  return substitute(a:entry[:-7], '\m/', '.', 'g')
endfunction

function! java_helper#db_to_item(fullname)
  return {
        \ 'fname': a:fullname,
        \ 'sname': java_helper#_simple_name(a:fullname),
        \ 'pname': java_helper#_package_name(a:fullname),
        \ 'pweight': java_helper#_get_weight(a:fullname),
        \ 'methods': []
        \ }
endfunction

function! java_helper#db_load(jarfile)
  let table = java_helper#db_load_jar(a:jarfile)
  return map(table, 'java_helper#db_to_item(v:val)')
endfunction

function! java_helper#db_match_by_shortname(item, shortname)
  let name = a:item['sname']
  return stridx(name, a:shortname) >= 0 && stridx(name, '$') < 0
endfunction

function! java_helper#db_select_class1(db, shortname)
  let retval = []
  for item in a:db
    if !java_helper#db_match_by_shortname(item, a:shortname)
      continue
    else
      call add(retval, item)
    endif
  endfor
  return retval
endfunction

function! java_helper#db_select_class2(db, shortname)
  let retval = []
lua << LUA_END
  local db = vim.eval('a:db')
  local shortname = vim.eval('a:shortname')
  local retval = vim.eval('retval')
  for item in db() do
    local name = item['sname']
    if name:find(shortname) and not name:find('%$') then
      retval:add(item)
    end
  end
LUA_END
  return retval
endfunction

function! java_helper#db_select_class(db, shortname)
  if has('lua')
    return java_helper#db_select_class2(a:db, a:shortname)
  else
    return java_helper#db_select_class1(a:db, a:shortname)
  endif
endfunction
