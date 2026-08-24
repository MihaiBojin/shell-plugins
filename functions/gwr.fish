function gwr -d 'Remove a worktree whose branch is finished, and the branch with it'
    argparse h/help f/force no-forge no-fetch all y/yes 'branch=' -- $argv
    or return 2
    if set -q _flag_help
        gw >&2
        return 0
    end

    set -l use_forge 1
    set -q _flag_no_forge; and set use_forge 0
    set -q _flag_no_fetch; and set use_forge 0
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
        _gw_sweep (set -q _flag_yes; and echo 1; or echo 0) $use_forge "$_flag_branch"
        return $status
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
        set -l out (git -C $main worktree remove --force $wt 2>&1)
        if test $status -ne 0
            if string match --quiet '*submodule*' -- "$out"
                _gw_say err "left $wt alone; it holds submodules, and --force would delete their git directories"
                echo "    if you mean it: git -C $main worktree remove --force $wt" >&2
            else
                _gw_say err "could not remove $wt: $out"
            end
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
