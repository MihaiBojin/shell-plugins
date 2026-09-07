function _gw_step_out -a wt main -d 'Leave $wt for $main when that is where we are standing'
    # `git worktree remove` will take the directory out from under the shell
    # that is sitting in it, leaving $PWD pointing at nothing. Zsh has always
    # stepped out first; this is the same move.
    set -l here (path resolve $wt | string collect)
    set -l cwd (path resolve $PWD | string collect)
    if test "$cwd" = "$here"; or string match --quiet -- "$here/*" "$cwd"
        cd $main
    end
end
