" Program: Subversion commit helper.
" Description: The is a combination of commands that make it easier to handle commiting files
" to a Subversion repository. One of the features of SVN is that does atomic commits - so you can
" commit a group of files in one commit command, and that they all will be grouped together as 
" files that were commited. These scripts make it easy for you to execute SVN commands on single files
" or groups of files from within vim.
" Commands:
"   CommitFile(): When executed this function will open a commit log window (to type in a description of the commit).
"   When that window is saved/commited the file is then commited to SVN. This command is visual select friendly, so you
"   can use it to commit a group of files.
"   CommandFiles(): A visual select friendly command that will execute an SVN command on a group of files. When executed
"   a prompt will appear to take in an SVN command (delete, rm, add, log, etc).
" Version: initial release.

" recordings - /*{{{*/
" Do a diff of the file under the cursor with whats on the Subversion REMOTE repository
let @r='^wv$bbbh"cy$bbbvw$h"by:call SVN_GetVersion('. "'" .'cb'. "'" .')'
" Do a diff of the file under the cursor with whats on the Subversion local repository
" let @d='^w"cy$:let @x=ParseOutFilename("c"):let @y=ParseOutPath("c"):sp y.svn/text-base/x.svn-base:vert diffs c_'
let @d=':call SVN_CompareToLatest(SVN_ParseFullPath(getline(".")))'
" Do the diff with the java 1.1 code
" let @l='^wv$bbbh"cy$bbbvw$h"bry:sp cb:vert diffs c:/lti/dev/suzie/src/ui/'
" Just open the file in this line
let @o='^wv$bbbh"cy$bbbvw$h"by:sp cb_'
" Close both the windows
let @n=':q:q'
" Do a diff of the current file with the current SVN folder.
let @z=':vert diffs %F/a.svn/text-base/$a.svn-base'
ca rq :exe "r ! ". SVN_command ." st -q" 
ca rr :exe "r ! ". SVN_command ." st"
" let @c='v$hy:call CommitFile(""")'
" Make a patch for the changes I made to the file under the cursor.
" let @p='^wyW:!svn diff " > temp.patch'
" Apply the patch with a command like:
" Like to have more context for my diffs, then I could use like a -F 5
" let	:!c:/cygwin/bin/patch.exe -p6 -l -F 2 " temp.patch
"/*}}}*/

" The actual source control command:
if !exists('SVN_command')
  let SVN_command='/usr/bin/svn'
endif

" TODO show the history of the file(to pick a version to diff with).
" TODO convert the macros to leader commands.
" TODO handle text with \w\s\+.\+ like:
" M      showmarks.vim
" A  +   scm-plugin.vim
" TODO after executing a command, delete the selected text and replace it with
" the results.

" do a diff of a selected file with a previous revision of the file.
function! SVN_GetVersion(filename)
  let convertedfile = substitute(a:filename,"\\","\/","g")
  let ver = input("Version:") " need an extra one because the recording eats the extra ^M
  let ver = input("Version:")
  let oldver = convertedfile .".". ver
  if ver != ""
    execute "sp ". oldver
    execute "normal ggdG"
    execute "r !". g:SVN_command ." cat -r ". ver ." ". convertedfile
    execute "set bt=nofile"
    execute "normal ggdd"
    execute "vert diffsplit ". convertedfile
    execute "normal _"
  endif
endfunction

function! SVN_CompareToLatest(filename)
  let convertedfile = substitute(a:filename,"\\","\/","g")
  let oldver = convertedfile .".latest"
  execute "sp ". oldver
  execute "normal ggdG"
  execute "r !". g:SVN_command ." cat ". convertedfile
  execute "set bt=nofile"
  execute "normal ggdd"
  execute "vert diffsplit ". convertedfile
  execute "normal _"
endfunction

function! SVN_GetRepositoryInfo()
  " Make the status call to fetch in some things.
  let tempFile = tempname()
  exe "!". g:SVN_command ." st > ". tempFile
  exe "sp ". tempFile

  call SVN_ProcessStatusQuery()
endfunction

function! SVN_ProcessStatusQuery()
  " each svn entry has the following info associated with it:
  " -status
  " -pathname
  exe "1"
  let lastLine = line("$") == 1
  let foundLastLine = lastLine
  while line("$") != 1 || (foundLastLine && lastLine)
    exe "1"
    exe "normal yy"
    let line = @"
    if col("$") > 8
      let status = strpart(line,0,1)
      let path = strpart(line,7,col("$") - 8)
      call SVN_AddEntry(status,path)
      exe "delete"
    endif
    if !foundLastLine
      let lastLine = line("$") == 1
      let foundLastLine = lastLine
    else
      let lastLine = 0
    endif
  endwhile
endfunction

function! SVN_AddEntry(status,path)
  " Make up the entry object and add it to our store of
  " entries.
  echoe "status = ". a:status ." path = ". a:path
endfunction

" SvnEntry/*{{{*/
function! NewSvnEntry(status,path)
  let name = "SvnEntry". NewObjectRef()
  SetVar(name,"status",a:status)
  SetVar(name,"path",a:path)
  return name;
endfunction
"/*}}}*/
" Commit dialogs/*{{{*/
function! CommandFiles() range
	" parse out the files in the lines, and send them on to CommitFile
	let n = a:firstline
	let files = ""
	while n <= a:lastline
    let files = files .' '. SVN_ParseFullPath(getline(n))
		let n = n + 1
	endwhile

  let command = input("Command:")
  if command != ""
    call <SID>CommandFile(command,files)
  endif
endfunction

function! CommitFiles() range
	" parse out the files in the lines, and send them on to CommitFile
	let n = a:firstline
	let files = ""
	while n <= a:lastline
		let matchedColumn = match(getline(n),".  .   ")
		if matchedColumn != -1
			exe n
			exe 'normal ^'. (matchedColumn+7) .'l'
			exe 'normal y$'
			let files = files .' '. @"
		endif
		let n = n + 1
	endwhile

	call <SID>CommitFile(files)
endfunction

function! <SID>SVNMakeAutos(filename)
  " Make any automatic function calls:
  " - automatically show commit message when closing the 'commit' file.
  augroup CommitGRP
    exe "autocmd BufWinLeave __Commit__ call <SID>SVN_CommitMessage('". a:filename ."')"
  augroup end
endfunction

if !exists('SVN_Loaded')
  let SVN_Loaded=1
  call <SID>SVNMakeAutos('')
endif

" do an arbitrary command sent to SVN.
function! <SID>CommandFile(command,filename)
  echom "r !". g:SVN_command ." ". a:command ." ". a:filename
  execute "r !". g:SVN_command ." ". a:command ." ". a:filename
endfunction

" do an 'svn commit', with a message
function! <SID>CommitFile(filename)
  echo "splitting file __Commit__"
  exe "silent! split __Commit__"
  exe "set ff=unix"
  exe "set wrap"
  exe "autocmd! CommitGRP"
  call <SID>SVNMakeAutos(a:filename)
endfunction

" Method that opens a new buffer where the user can then enter a commit message.
function! <SID>SVN_CommitMessage(filename)
  " TODO factor user/pass into global variables.
  if input("Commit files?") == "y"
		execute "!". g:SVN_command ." ci -F __Commit__ ". a:filename
  endif
endfunction

function! <SID>ParseOutFilename(fileAndPath)
  if a:fileAndPath =~ "/"
    let sub = substitute(a:fileAndPath,"^/","","")
    return substitute(sub,"^.*/","","")
  else
    return a:fileAndPath
  endif
endfunction

function! <SID>ParseOutPath(fileAndPath)
  let matchstart = match(a:fileAndPath,"^.*/")
  if matchstart != -1
    let matchend = matchend(a:fileAndPath,"^.*/")
    return strpart(a:fileAndPath,matchstart,matchend-matchstart)
  else
    return ""
  endif
endfunction

function! SVN_ParseFullPath(line)
  return substitute(a:line,'^\s*\c.[ +]\{1,}',"","")
endfunction

function! TestFullPath()
  " put your curser in this block somwhere and then type ":call VUAutoRun()"
  call VUAssertEquals(SVN_ParseFullPath('!     /to/path/filename'),'/to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M     /to/path/filename'),'/to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M +   /to/path/filename'),'/to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M + /to/path/filename'),'/to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M /to/path/filename'),'/to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M to/path/filename'),'to/path/filename')
  call VUAssertEquals(SVN_ParseFullPath('M   pom.xml'),'pom.xml')
  call VUAssertEquals(SVN_ParseFullPath('  M   pom.xml'),'pom.xml')
endfunction

function! TestParseFunctions()
  " put your curser in this block somwhere and then type ":call VUAutoRun()"
  call VUAssertEquals(s:ParseOutFilename('pom.xml'),'pom.xml')
  call VUAssertEquals(s:ParseOutFilename('filename'),'filename')
  call VUAssertEquals(s:ParseOutPath('filename'),'')
  call VUAssertEquals(s:ParseOutFilename('filename.opt'),'filename.opt')
  call VUAssertEquals(s:ParseOutPath('filename.opt'),'')
  call VUAssertEquals(s:ParseOutFilename('/filename'),'filename')
  call VUAssertEquals(s:ParseOutPath('/filename'),'/')
  call VUAssertEquals(s:ParseOutFilename('/filename.opt'),'filename.opt')
  call VUAssertEquals(s:ParseOutPath('/filename.opt'),'/')
  call VUAssertEquals(s:ParseOutFilename('/path/filename'),'filename')
  call VUAssertEquals(s:ParseOutPath('/path/filename'),'/path/')
  call VUAssertEquals(s:ParseOutFilename('/path/filename.opt'),'filename.opt')
  call VUAssertEquals(s:ParseOutPath('/path/filename.opt'),'/path/')
  call VUAssertEquals(s:ParseOutFilename('on/path/filename.opt'),'filename.opt')
  call VUAssertEquals(s:ParseOutPath('on/path/filename.opt'),'on/path/')
  call VUAssertEquals(s:ParseOutFilename('on/path/filename.opt'),'filename.opt')
  call VUAssertEquals(s:ParseOutPath('on/path/filename.opt'),'on/path/')
endfunction

"/*}}}*/

" General function.
" A function to switch between rails controller and view quickly
function! SwitchPanes(file,method)
  " TODO parse out the controller name
  let control = GetController(file)
  " TODO parse out the path.
endfunction

" From a filename, pull the controller name out.
" Of the form */app/controllers/{controller}_controller.rb
function! GetController(file)
  let startmatch = match(a:file,"app\/controllers\/\(\w\+\)_controller.rb")
  return ''
endfunction

function! TestGetController()
  call VUAssertEquals(GetController(''),'')
  call VUAssertEquals(GetController('app/biz_controller.rb'),'')
  call VUAssertEquals(GetController('/app/biz_controller.rb'),'')
  call VUAssertEquals(GetController('/app/controllers/biz_controller.rb'),'biz')
  call VUAssertEquals(GetController('app/controllers/biz_controller.rb'),'biz')
endfunction

" vim: set fdm=marker ts=2 sw=2 et ai:
