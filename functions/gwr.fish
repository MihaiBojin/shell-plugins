function gwr -d 'Remove a worktree whose branch is finished, and the branch with it'
    argparse h/help f/force no-forge fetch no-fetch n/dry-run all y/yes 'branch=' -- $argv
    or return 2
    if set -q _flag_help
        gw >&2
        return 0
    end

    set -l use_forge 1
    set -q _flag_no_forge; and set use_forge 0
    if set -q git_worktree_forge
        contains -- "$git_worktree_forge" no false off 0; and set use_forge 0
    end

    if set -q _flag_all
        if set -q _flag_force
            # --all never removes a checkout that is not finished, so there is
            # nothing for --force to override.
            _gw_say err '--all takes no --force'
            return 2
        end

        # The sweep decides against the head branch, so how fresh that is
        # decides what it reaps. Same policy as gwa, minus its `full` step:
        # there is no NAME to look for on the remote here, only the head
        # branch to keep current.
        set -l mode base
        set -q git_worktree_fetch; and set mode $git_worktree_fetch
        set -q _flag_fetch; and set mode always
        set -q _flag_no_fetch; and set mode no
        set -l online 1
        contains -- "$mode" no false off 0; and set online 0

        # Offline means offline. The forge is the one check that needs the
        # network, so --no-fetch turning off the fetch but leaving a call to
        # GitHub behind would be a promise half kept.
        test "$online" = 0; and set use_forge 0

        # A branch name here is the mistake the flag exists for, and sweeping
        # every finished worktree is much more than the person asking for one
        # of them wanted.
        if set -q argv[1]
            _gw_say err "gwr --all takes no positional arguments — did you mean: gwr --all --branch $argv[1]"
            return 2
        end

        # --dry-run wins over --yes whichever order they arrive in: between two
        # flags that contradict each other, the one that removes nothing is the
        # one to obey.
        set -l go 0
        set -q _flag_yes; and set go 1
        set -q _flag_dry_run; and set go 0

        _gw_sweep $go $use_forge "$_flag_branch" $online
        return $status
    end

    # Every flag that belongs to the sweep, refused here rather than accepted
    # and ignored. The single form never fetches — it resolves the head branch
    # offline — and it asks about the one worktree it was given, so none of
    # these would do anything. The forge check is the one thing that reaches
    # the network, and --no-forge is what turns it off.
    for flag in fetch no-fetch dry-run yes branch
        if set -q _flag_(string replace -a -- - _ $flag)
            _gw_say err "--$flag belongs to gwr --all"
            return 2
        end
    end

    if test (count $argv) -gt 1
        _gw_say err 'too many arguments — usage: gwr [PATH|QUERY]'
        return 2
    end

    # An existing directory is the worktree; anything else is a query for the
    # picker. That is what lets `gwr <path>` work on a repository the shell is
    # not standing in.
    set -l wt
    if test -n "$argv[1]" -a -d "$argv[1]"
        set wt (path resolve $argv[1])
    else
        if not git rev-parse --git-dir >/dev/null 2>&1
            _gw_say err 'not inside a git repository'
            return 1
        end
        set wt (_gw_pick 'remove>' "$argv[1]"); or return 1
    end

    set -l main (_gw_main_worktree $wt)
    if test -z "$main"
        _gw_say err "not a git worktree: $wt"
        return 1
    end

    # Every question — which remote, which head branch, is this branch finished
    # — is asked of the repository the worktree belongs to, not of the shell's.
    set -l branch ''
    set -l flags ''
    for record in (_gw_records $wt)
        set -l fields (string split \t -- $record)
        test (path resolve $fields[1]) = "$wt"; or continue
        set branch $fields[3]
        set flags $fields[4]
        break
    end

    set -l remote (_gw_remote $main)
    set -l head_ref (_gw_head_branch "$remote" 0 $main)
    set -l head_name (string replace -r "^$remote/" '' -- "$head_ref")

    _gw_clean_refusal $wt "$branch" "$flags" (path resolve $PWD) $main "$head_name"
    set -l refusal $_gw_reply

    # Locked is never worked around: you locked it deliberately, and git itself
    # wants --force twice.
    if test "$refusal" = 'is locked'
        _gw_say err "not removing $wt — it $refusal"
        return 1
    end

    if test -n "$refusal"; and not set -q _flag_force
        _gw_say err "not removing $wt"
        echo "  it $refusal" >&2
        echo "  remove it anyway with:" >&2
        echo "    gwr --force $wt   (the branch is kept)" >&2
        return 1
    end

    if set -q _flag_force
        # --force never deletes a branch. It overrides the refusal to remove a
        # checkout, which is recoverable: the branch still exists and `gwa NAME`
        # brings the worktree back.
        if test -z "$branch"
            set -l sha (git -C $wt rev-parse --short HEAD 2>/dev/null)
            _gw_say warn "$wt is detached; nothing will refer to $sha afterwards; keep it first with:"
            echo "      git -C $main branch NAME $sha" >&2
        end
        # Checked before the removal, not after it. `git worktree remove
        # --force` walks past git's own submodule refusal and deletes
        # .git/worktrees/<id>/modules/* with the checkout — the submodule's only
        # copy of anything committed there, which nothing brings back and fsck
        # does not notice. Reading it out of git's error afterwards would mean
        # reading an error git never prints.
        #
        # Not asked of the main worktree: its git directory is the repository's
        # own, so its modules/ holds submodules nothing here is removing — and
        # git refuses to remove a main worktree anyway, for a better reason
        # than this one would give.
        set -l gitdir ''
        test (path resolve $wt) != (path resolve $main)
        and set gitdir (git -C $wt rev-parse --absolute-git-dir 2>/dev/null)
        if test -n "$gitdir"; and test -d "$gitdir/modules"
            _gw_say err "$wt holds submodule git directories — --force would delete them with it"
            echo "  push the submodules' commits somewhere first, then:" >&2
            echo "    git -C $main worktree remove --force $wt" >&2
            return 1
        end

        set -l out (git -C $main worktree remove --force $wt 2>&1)
        if test $status -ne 0
            _gw_say err "could not remove $wt: $out"
            return 1
        end
        _gw_prune_upto $wt $main
        _gw_say info "removed $wt"(test -n "$branch"; and echo " (branch $branch kept)"; or echo '')
        _gw_suggest_prune $main
        return 0
    end

    if test -z "$head_ref"
        _gw_say err "not removing $wt — cannot work out this repository's head branch"
        _gw_say err "  record it with: git -C $main remote set-head $remote --auto"
        return 1
    end

    if not _gw_is_finished "$branch" "$head_ref" "$head_name" $use_forge $main
        _gw_say err "not removing $wt"
        echo "  branch $branch — $_gw_reply" >&2
        echo "  the checkout is where unfinished work lives; remove it anyway with:" >&2
        echo "    gwr --force $wt   (the branch is kept)" >&2
        return 1
    end
    set -l why $_gw_reply

    echo "Remove worktree $wt" >&2
    echo "  branch $branch — $why; it will be deleted" >&2
    read --local --prompt-str='Proceed? [y/N] ' answer
    if not string match --quiet --regex '^[Yy]' -- "$answer"
        _gw_say info 'left alone'
        return 1
    end

    _gw_remove_one $wt "$branch" "$why"
    set -l rc $status
    _gw_suggest_prune $main
    return $rc
end
