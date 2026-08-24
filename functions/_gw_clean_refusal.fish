function _gw_clean_refusal -a wt branch flags cwd main head -d 'Why $wt must not be touched at all'
    # Into $_gw_reply; empty when there is no such reason. These are the
    # refusals that have nothing to do with whether the branch was merged, and
    # none of them is worked around.
    set -g _gw_reply ''
    set -l here (path resolve $wt)

    if test "$cwd" = "$here"; or string match --quiet -- "$here/*" $cwd
        set -g _gw_reply 'is the worktree you are standing in'
        return 0
    end
    if test -n "$main"; and test (path resolve $main) = "$here"
        set -g _gw_reply 'is the main worktree'
        return 0
    end
    if test -z "$branch"
        set -g _gw_reply 'has a detached HEAD'
        return 0
    end
    if test "$branch" = "$head"
        set -g _gw_reply 'is the head branch'
        return 0
    end
    if string match --quiet '*locked*' -- $flags
        set -g _gw_reply 'is locked'
        return 0
    end
    if string match --quiet '*prunable*' -- $flags
        # Its directory is already gone; the branch stays, which is the
        # conservative half.
        set -g _gw_reply 'is stale — its directory is gone'
        return 0
    end

    _gw_work_in_progress $wt $branch
    return 0
end
