function _gw_main_worktree -a dir -d 'The main worktree of the repository containing $dir (default: $PWD)'
    # `git worktree list --porcelain` always names the main checkout first, and
    # _gw_dest relies on that.
    test -n "$dir"; or set dir $PWD
    set -l out (git -C $dir worktree list --porcelain 2>/dev/null); or return 1
    set -q out[1]; or return 1
    string match --quiet 'worktree *' -- $out[1]; or return 1
    string replace 'worktree ' '' -- $out[1]
end
