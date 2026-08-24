function _gw_records -a dir -d 'Every worktree of this repository as path\tsha\tbranch\tflags'
    # The one place `git worktree list --porcelain` is parsed. <branch> is empty
    # for a detached or bare checkout; <flags> is a comma-separated subset of
    # bare,detached,locked,prunable. The main checkout comes first.
    test -n "$dir"; or set dir $PWD
    set -l out (git -C $dir worktree list --porcelain 2>/dev/null); or return 1

    set -l wt ''
    set -l sha ''
    set -l branch ''
    set -l flags ''
    set -l seen
    set -l found 0

    function __gw_emit_record --no-scope-shadowing
        test -n "$wt"; or return 0
        set -l key (path resolve $wt)
        contains -- $key $seen; and return 0
        set -a seen $key
        set found 1
        printf '%s\t%s\t%s\t%s\n' $wt $sha $branch (string join ',' -- $flags)
    end

    for line in $out
        switch $line
            case 'worktree *'
                __gw_emit_record
                set wt (string replace 'worktree ' '' -- $line)
                set sha ''
                set branch ''
                set flags
            case 'HEAD *'
                set sha (string replace 'HEAD ' '' -- $line)
            case 'branch *'
                set branch (string replace -r '^branch (refs/heads/)?' '' -- $line)
            case bare detached
                set -a flags $line
            case 'locked*'
                set -a flags locked
            case 'prunable*'
                set -a flags prunable
        end
    end
    __gw_emit_record
    functions -e __gw_emit_record

    test $found -eq 1
end
