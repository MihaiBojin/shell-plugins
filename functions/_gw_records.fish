function _gw_records -a dir -d 'Every worktree of this repository, NUL-separated, as path/sha/branch/flags'
    # The one place `git worktree list` is parsed. Each record holds four
    # fields separated by US (0x1f); records are separated by NUL, so a caller
    # reads them with `string split0` and their fields with `string split \x1f`.
    #
    # <branch> is empty for a detached or bare checkout; <flags> is a
    # comma-separated subset of bare,detached,locked,prunable. The main
    # checkout comes first, and _gw_dest relies on that.
    #
    # --porcelain -z rather than --porcelain: without -z git ends every
    # attribute with a newline, so a worktree whose directory name contains one
    # arrives as two lines and parses into two worktrees, neither of which
    # exists. NUL between records carries that path back out whole, and the
    # fields inside a record are separated by US because a directory name can
    # hold a tab and git hands it over without comment.
    test -n "$dir"; or set dir $PWD
    set -l out (git -C $dir worktree list --porcelain -z 2>/dev/null | string split0); or return 1

    set -l us (printf '\x1f')
    set -l records
    set -l seen
    set -l wt ''
    set -l sha ''
    set -l branch ''
    set -l flags

    function __gw_emit_record --no-scope-shadowing
        test -n "$wt"; or return 0
        # A worktree listed twice under different spellings of the same
        # directory is still one worktree.
        set -l key (path resolve $wt | string collect)
        contains -- $key $seen; and return 0
        set -a seen $key
        # Concatenated rather than joined through a command substitution: a
        # substitution splits its output on newlines, so a path holding one
        # would arrive here as two records. $joined is quoted so a worktree
        # with no flags still contributes a fourth field.
        set -l joined (string join , -- $flags)
        set -a records "$wt$us$sha$us$branch$us$joined"
    end

    for line in $out
        switch $line
            case 'worktree *'
                __gw_emit_record
                # string collect, for the same reason: this is the one
                # field git will hand back with a newline in it.
                set wt (string replace 'worktree ' '' -- $line | string collect)
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

    set -q records[1]; or return 1
    string join0 $records
end
