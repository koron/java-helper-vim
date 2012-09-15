" vim:set ts=8 sts=2 sw=2 tw=0 et:

scriptencoding utf-8

let s:revision = 1
let s:classes = {}

"###########################################################################

" get JAVA_HOME value.
function! java_helper#_get_home()
  if &shellslash
    return substitute($JAVA_HOME, '\\', '/', 'g')
  else
    return $JAVA_HOME
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
  let path = java_helper#_get_home() . '/jre/lib/' . a:name
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
    " arrange format of each line (full class name).
    call map(lines, 'substitute(v:val, "\\m/", ".", "g")')
    call map(lines, 'substitute(v:val, "\\m\\.class$", "", "")')
    " remove anonymous classes.
    call filter(lines, 'v:val !~# "\\m\\$\\d\\+$"')
    return lines
  endif
endfunction

" setup internal data for this plugin.
function! java_helper#setup(force)
  if !a:force && len(s:classes) != 0
    return
  endif
  let jarfile = java_helper#find_jarfile('rt.jar')
  let classes = java_helper#list_classes(jarfile)
  let s:classes = java_helper#assort_by_shortname(classes)
endfunction

function! java_helper#assort_by_shortname(classes)
  let table = {}
  for class in a:classes
    let name = java_helper#_simple_name(class)
    call java_helper#_add(table, name, class)
  endfor
  for names in values(table)
    call sort(names, 'java_helper#compare_class')
  endfor
  return table
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
  return idx >= 0 ? idx : -3
endfunction

function! java_helper#omni_second(base)
  call java_helper#setup(0)
  let short_keys = keys(s:classes)
  call filter(short_keys, 'v:val !~# "\\$"')
  call sort(short_keys)

  let match1 = []
  let match2 = []
  let match3 = []

  for short_name in short_keys
    if short_name !~# a:base
      continue
    endif
    let values = s:classes[short_name]
    for full_name in values
      let item = { 
            \ 'word': short_name, 
            \ 'menu': java_helper#package_name(full_name),
            \ '_order': java_helper#_get_weight(full_name)
            \ }
      if item['_order'] >= 500
        continue
      endif
      if short_name ==# a:base
        call add(match1, item)
      else
        call add(match3, item)
      endif
    endfor
  endfor

  call sort(match1, 'java_helper#compare_items')
  call sort(match2, 'java_helper#compare_items')
  call sort(match3, 'java_helper#compare_items')

  return { 'words': match1 + match2 + match3, 'refresh': 'always' }
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
  let diff = java_helper#strcmp(a:item1['word'], a:item2['word'])
  return diff
endfunction
