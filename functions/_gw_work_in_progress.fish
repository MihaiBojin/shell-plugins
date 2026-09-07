function _gw_work_in_progress -a wt branch -d 'Work in $wt that removing the checkout would interrupt'
    # Into $_gw_reply; empty when there is none. Strictly, only the first is
    # lost by removing a worktree — a stash lives in the repository's own refs —
    # but both mean the same thing: somebody is still working here.
    set -g _gw_reply ''

    # --porcelain counts untracked files and ignores gitignored ones, which is
    # exactly the set that makes `git worktree remove` refuse.
    set -l dirty (git -C $wt status --porcelain 2>/dev/null)
    if set -q dirty[1]
        set -g _gw_reply 'has uncommitted changes'
        return 0
    end

    test -n "$branch"; or return 0

    set -l stashes (_gw_stashes_for $branch $wt)
    if test "$stashes" -eq 1
        set -g _gw_reply 'has a stash entry parked on it'
    else if test "$stashes" -gt 1
        set -g _gw_reply "has $stashes stash entries parked on it"
    end
    return 0
end
