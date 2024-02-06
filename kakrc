# User mode mappings
map global user -docstring 'find' f ':find '
map global user -docstring 'grep' g ':grep '
map global user -docstring 'Select surrounding braces' b '<a-a>B'
map global user -docstring 'Select surrounding parens' p '<a-a>b'
map global user -docstring 'Delete till end of line' d 'Gld'
map global user -docstring 'goto error' e ':lsp-find-error<ret>'
map global user -docstring 'hover' h ':lsp-hover<ret>'
map global user -docstring 'lsp mode' l ':enter-user-mode lsp<ret>'
map global user -docstring 'Comment lines' / ':comment-line<ret>'

# General useful options
set-option global tabstop 4
set-option global indentwidth 4
set-option global aligntab false
hook global InsertChar \t %{ exec -draft -itersel h@ }
hook global InsertKey <backspace> %{ try %{ execute-keys -draft <a-h><a-k> "^\h+.\z" <ret>I<space><esc><lt> }}

add-highlighter global/ number-lines -hlcursor # Line numbers
add-highlighter global/ wrap -word -indent # Soft wrap long lines
set-face global MatchingChar bright-yellow+b
add-highlighter global/ show-matching
set-option global scrolloff 1,3 # Keep some context around the cursor
set global grepcmd 'rg -Hn --trim'
define-command find -docstring "find files" -params 1 %{ edit %arg{1} }
complete-command find shell-script-candidates %{ rg --files-with-matches .}

define-command -params .. runInClient %{
    evaluate-commands "run %arg{@}"
}

hook global ModuleLoaded tmux %{
    set-option global windowing_placement vertical

    define-command -override -params .. runInClient %{
        terminal kak -c %val{session} -e "run %arg{@}"
    }
}

define-command -params .. run %{ evaluate-commands %sh{
    output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-fifo.XXXXXXXX)/fifo
    mkfifo ${output}
    ( eval "$@ && echo '\nCommand succeeded' || echo '\nCommand failed'" > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null
    printf %s\\n "evaluate-commands %{
        edit! -fifo ${output} *fifo*
        hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${output}) } }
    }"
}}

declare-option -hidden str builddir
set-option global builddir 'clang'
define-command -params 1 compile %{ runInClient cmake --build %opt{builddir} --target  %arg{1} -- -j 14 }

declare-option -hidden str executableName
declare-option -hidden str executableArgs
define-command -params 1.. execute %{
    set-option global executableName %sh{ find ${kak_opt_builddir}/src -type f -perm +111 | grep $1 }
    set-option global executableArgs %sh{ echo "$@" | cut -s -f2- -d' '}
    runInClient %opt{executableName} %opt{executableArgs}
}

map global user -docstring 'run' r ':runInClient '
map global user -docstring 'compile' c ':compile '
map global user -docstring 'execute' x ':execute '

# Language server protocol
eval %sh{kak-lsp --kakoune -s $kak_session}
hook global WinSetOption filetype=(rust|python|go|javascript|typescript|c|cpp) %{
    lsp-enable-window
}

# Tab to auto complete when available
hook global InsertCompletionShow .* %{
    map window insert <tab> <c-n>
    map window insert <s-tab> <c-p>
}

# When not popping up, tab to insert a tab
hook global InsertCompletionHide .* %{
    unmap window insert <tab> <c-n>
    unmap window insert <s-tab> <c-p>
}

define-command ide %{
    rename-client main
    tmux-terminal-horizontal kak -c %val{session} -e "rename-client tools"
    tmux-focus main

    set global toolsclient tools
    set global jumpclient main
}
