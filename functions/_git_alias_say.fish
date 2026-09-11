function _git_alias_say -a level -d 'Print a git-alias message on stderr'
    # One place decides what these messages look like, and they all go to
    # stderr so `gb` and the pickers stay pipeable. Colour only when
    # _git_alias_colour says stderr takes it: an err or warn caught in a pipe
    # is read as text, and set_color answers from $TERM rather than from where
    # the output is going.
    set -l text (string join ' ' -- $argv[2..-1])

    if not _git_alias_colour
        echo "git-alias: $text" >&2
        return
    end

    set -l colour normal
    switch $level
        case err
            set colour red
        case warn
            set colour yellow
    end
    echo (set_color $colour)"git-alias:"(set_color normal)" $text" >&2
end
