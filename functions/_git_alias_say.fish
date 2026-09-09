function _git_alias_say -a level -d 'Print a git-alias message on stderr'
    # One place decides what these messages look like, and they all go to
    # stderr so `gb` and the pickers stay pipeable.
    set -l colour normal
    switch $level
        case err
            set colour red
        case warn
            set colour yellow
    end
    echo (set_color $colour)"git-alias:"(set_color normal)" "(string join ' ' -- $argv[2..-1]) >&2
end
