function _gw_main_worktree -a dir -d 'The main worktree of the repository containing $dir (default: $PWD)'
    # `git worktree list --porcelain` always names the main checkout first, and
    # _gw_dest relies on that.
    #
    # -z, and split on NUL: without it git ends every attribute with a newline,
    # so a checkout whose directory name holds one arrives as two elements and
    # this returns the half before the newline. Callers still have to collect
    # what comes back — a command substitution splits on newlines too.
    test -n "$dir"; or set dir $PWD
    set -l out (git -C $dir worktree list --porcelain -z 2>/dev/null | string split0); or return 1
    set -q out[1]; or return 1
    string match --quiet 'worktree *' -- $out[1]; or return 1
    string replace 'worktree ' '' -- $out[1]
end
