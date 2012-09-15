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
  if a:name =~# '^java\.awt\.' | return 110 | endif
  if a:name =~# '^java\.' | return 100 | endif
  if a:name =~# '^javax\.' | return 200 | endif
  if a:name =~# '^android\.' | return 300 | endif
  if a:name =~# '^com\.\(sun\|oracle\)\.' | return 900 | endif
  return 999
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

" jar内の(主要)クラス一覧を取得する
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

function! java_helper#fullname(short_name)
  call java_helper#setup(0)
  return get(s:classes, a:short_name, [])
endfunction
