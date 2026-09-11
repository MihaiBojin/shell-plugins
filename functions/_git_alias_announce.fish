function _git_alias_announce -d 'Print the command a git-alias function is about to run'
    # These three replaced abbreviations, and an abbreviation showed you what it
    # expanded to before it ran. The line is what you get instead, with the
    # parts an abbreviation could not resolve -- the default branch -- already
    # filled in.
    #
    # stderr so the commands stay pipeable, and dim only when stderr is a
    # terminal: a redirected line is read by something that wants text, not
    # escapes.
    set -l line (string join ' ' -- $argv)
    if isatty stderr
        echo (set_color --dim)$line(set_color normal) >&2
    else
        echo $line >&2
    end
end
