function _gw_remove_one -a wt branch why -d 'Remove worktree $wt and delete its finished branch'
    # Order matters: the worktree goes first, because git will not delete a
    # branch that is checked out somewhere.
    set -l main (_gw_main_worktree $wt | string collect); or set main (_gw_main_worktree | string collect)
    if test -z "$main"
        _gw_say err "cannot locate the main worktree for $wt"
        return 1
    end

    # No --force here, ever. `git worktree remove` refuses a worktree holding
    # modified or untracked files — the same set _gw_clean_refusal asked about —
    # so a refusal at this point means something appeared since that check, and
    # forcing past it would delete work nobody has seen. `gwr --force` is the
    # deliberate way to do that.
    set -l out (git -C $main worktree remove $wt 2>&1)
    if test $status -ne 0
        set -l dirty (git -C $wt status --porcelain 2>/dev/null)
        if set -q dirty[1]
            _gw_say warn "$wt has work in it after all; leaving it"
        else if string match --quiet '*submodule*' -- "$out"
            _gw_say warn "left $wt alone; it holds submodules, and --force would delete their git directories"
        else
            _gw_say warn "left $wt alone; remove it deliberately with: gwr --force $wt"
        end
        return 1
    end
    echo (set_color green)"[✓]"(set_color normal)" removed $branch — $why" >&2

    _gw_prune_upto $wt $main

    # Read the sha before the delete: afterwards there is no name left to
    # resolve it from.
    set -l was (git -C $main rev-parse --short refs/heads/$branch 2>/dev/null)

    # -d first, then -D. `git branch -d` refuses a squash-merged branch on
    # principle, because from where git stands it is unmerged — and check 2 of
    # the predicate is precisely the proof that it is not. A branch that failed
    # the checks never reaches this function, so -D here is never a guess.
    if git -C $main branch -d $branch >/dev/null 2>&1
        or git -C $main branch -D $branch >/dev/null 2>&1
        if test -n "$was"
            _gw_say info "deleted branch $branch (was $was)"
            # Printed per branch rather than once per run, so the way back to any
            # one of them can be copied on its own. This is the whole escape
            # hatch: there is no flag that keeps a finished branch.
            echo "    restore: git branch $branch $was" >&2
        else
            _gw_say info "deleted branch $branch"
        end
        return 0
    end

    _gw_say warn "removed the worktree but could not delete $branch"
    return 0
end
