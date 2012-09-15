" vim:set ts=8 sts=2 sw=2 tw=0 et:

scriptencoding utf-8

let s:revision = 1
let s:classes = {}

"###########################################################################

" regulate path (convert Windows style to UNIX style if needs)
function! java_helper#regulate_path(path)
  if &shellslash
    return substitute(a:path, '\\', '/', 'g')
  else
    return a:path
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
  if a:name =~# '\M^sun.' | return 900 | endif
  return 499
endfunction

function! java_helper#compare_class(item1, item2)
  return java_helper#_get_weight(a:item1) - java_helper#_get_weight(a:item2)
endfunction

"###########################################################################

function! java_helper#revision()
  return s:revision
endfunction

" find jar file, return its full path.
function! java_helper#find_jarfile(name)
  let path = java_helper#regulate_path($JAVA_HOME) . '/jre/lib/' . a:name
  if filereadable(path)
    return path
  else
    return ''
  end
endfunction

" list all (important) classes in a jar file.
function! java_helper#list_classes(file)
  if a:file ==# '' || !filereadable(a:file)
    return []
  else
    let lines = split(system('jar -tf ' . a:file), '\n')
    " extract only classes
    call filter(lines, 'v:val =~# "\\.class$"')
    " remove anonymous classes.
    call filter(lines, 'v:val !~# "\\m\\$\\d\\+\\.class$"')
    " arrange format of each line (full class name).
    call map(lines, 'substitute(v:val, "\\m/", ".", "g")')
    call map(lines, 'substitute(v:val, "\\m\\.class$", "", "")')
    return lines
  endif
endfunction

function! java_helper#is_android()
  " TODO:
  return 0
endfunction

function! java_helper#list_jarfiles()
  let jars = []
  if java_helper#is_android()
    " TODO:
    let sdkdir = java_helper#regulate_path($ANDROID_SDK)
    call add(jars, sdkdir . '/platforms/android-16/android.jar')
  else
    call add(jars, java_helper#find_jarfile('rt.jar'))
  endif
  return jars
endfunction

" setup internal data for this plugin.
function! java_helper#setup(force)
  if !a:force && len(s:classes) != 0
    return
  endif
  let jars = java_helper#list_jarfiles()
  let table = {}
  for jar in jars
    let classes = java_helper#list_classes(jar)
    call java_helper#assort_by_shortname(table, classes)
  endfor
  let s:classes = table
endfunction

function! java_helper#assort_by_shortname(table, classes)
  for class in a:classes
    let name = java_helper#_simple_name(class)
    call java_helper#_add(a:table, name, class)
  endfor
  for names in values(a:table)
    call sort(names, 'java_helper#compare_class')
  endfor
  return a:table
endfunction

" get full class name by short name.
function! java_helper#fullname(short_name)
  call java_helper#setup(0)
  return get(s:classes, a:short_name, [])
endfunction

function! java_helper#omni_complete(findstart, base)
  if a:findstart
    return java_helper#omni_first()
  else
    return java_helper#omni_second(a:base)
  endif
endfunction

function! java_helper#omni_first()
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

function! java_helper#omni_second(base)
  call java_helper#setup(0)
  let short_keys = keys(s:classes)
  call filter(short_keys, 'v:val =~# a:base')
  call filter(short_keys, 'v:val !~# "\\$"')
  call sort(short_keys)

  let match1 = []
  let match2 = []
  let match3 = []

  for short_name in short_keys
    let values = s:classes[short_name]
    for full_name in values
      let item = {
            \ 'word': full_name,
            \ 'abbr': short_name,
            \ 'menu': java_helper#package_name(full_name),
            \ '_order': java_helper#_get_weight(full_name)
            \ }
      if item['_order'] >= 500
        continue
      endif
      if short_name ==# a:base
        call add(match1, item)
      else
        let idx = match(short_name, a:base)
        if idx == 0
          call add(match2, item)
        else
          call add(match3, item)
        endif
      endif
    endfor
  endfor

  call sort(match1, 'java_helper#compare_items')
  call sort(match2, 'java_helper#compare_items')
  call sort(match3, 'java_helper#compare_items')

  let retval = { 'words': match1 + match2 + match3, 'refresh': 'always' }
  let b:java_helper_last_omniretval = retval
  return retval
endfunction

function! java_helper#package_name(full_name)
  if a:full_name =~# '\.'
    return substitute(a:full_name, '\.[^.]*$', '', '')
  else
    return '<no package>'
  endif
endfunction

function! java_helper#strcmp(str1, str2)
  if a:str1 <# a:str2
    return -1
  elseif a:str1 ==# a:str2
    return 0
  else
    return 1
  endif
endfunction

function! java_helper#compare_items(item1, item2)
  let diff = a:item1['_order'] - a:item2['_order']
  if diff != 0
    return diff
  endif
  let diff = java_helper#strcmp(a:item1['menu'], a:item2['menu'])
  if diff != 0
    return diff
  endif
  let diff = java_helper#strcmp(a:item1['abbr'], a:item2['abbr'])
  if diff != 0
    return diff
  endif
  let diff = java_helper#strcmp(a:item1['word'], a:item2['word'])
  return diff
endfunction

" CompleteDone handler.
function! java_helper#complete_done()
  call java_helper#finish_complete()
endfunction

" add import statement if can, replace to short name.
function! java_helper#finish_complete()
  if !exists('b:java_helper_last_omnibase') ||
        \ !exists('b:java_helper_last_omniretval')
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
  unlet b:java_helper_last_omniretval
endfunction

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
