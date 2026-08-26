function _gw_plain_list -d "This repository's worktrees as mark/branch/path, without colour"
    # <mark> \t <branch> \t <path>, one per line.
    #
    # <mark> is `*` for the worktree you are standing in and a space otherwise;
    # <branch> is `(bare)`, `(detached)` or `?` when there is no branch. The
    # path is absolute and unshortened, so `gwl --list | cut -f3` feeds `cd`
    # directly — which is the whole reason this exists next to _gw_pick, whose
    # columns are shortened and coloured for a person reading a picker.
    set -l records (_gw_records | string split0); or return 1
    set -l us (printf '\x1f')
    set -l cwd (path resolve $PWD)

    for record in $records
        set -l fields (string split $us -- $record)
        set -l wt $fields[1]
        set -l branch $fields[3]
        set -l flags $fields[4]
        if test -z "$branch"
            if string match --quiet '*bare*' -- $flags
                set branch '(bare)'
            else if string match --quiet '*detached*' -- $flags
                set branch '(detached)'
            else
                set branch '?'
            end
        end
        set -l here (path resolve $wt)
        set -l mark ' '
        if test "$cwd" = "$here"; or string match --quiet -- "$here/*" $cwd
            set mark '*'
        end
        printf '%s\t%s\t%s\n' $mark $branch $wt
    end
end
