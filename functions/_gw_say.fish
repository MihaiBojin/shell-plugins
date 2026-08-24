function _gw_say -a level -d 'Print a gw message on stderr'
    # One place decides what a gw message looks like. Everything goes to stderr,
    # so `gw` and the pickers can be piped without their chatter joining the
    # output.
    set -l colour normal
    switch $level
        case err
            set colour red
        case warn
            set colour yellow
    end
    echo (set_color $colour)"gw:"(set_color normal)" "(string join ' ' -- $argv[2..-1]) >&2
end
