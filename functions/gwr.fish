function gwr -d 'Remove a worktree whose branch is finished, and the branch with it'
    argparse --name=gw h/help f/force delete-ignored no-forge fetch no-fetch n/dry-run all y/yes 'branch=' -- $argv
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

    # The sweep left, and its flags are named here rather than left to fall
    # into a generic parse error. The single form never fetches — it resolves
    # the head branch offline — and it asks about the one worktree it was
    # given, so none of these would have done anything here anyway.
    for flag in all fetch no-fetch dry-run yes branch
        if set -q _flag_(string replace -a -- - _ $flag)
            _gw_say err "--$flag belonged to the sweep; that is 'origin prune' now"
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
        set wt (path resolve $argv[1] | string collect)
    else
        if not git rev-parse --git-dir >/dev/null 2>&1
            _gw_say err 'not inside a git repository'
            return 1
        end
        _gw_pick 'remove>' "$argv[1]"; or return 1
        set wt $_gw_reply
    end

    set -l main (_gw_main_worktree $wt | string collect)
    if test -z "$main"
        _gw_say err "not a git worktree: $wt"
        return 1
    end

    # Before anything --force could reach: git cannot remove a main worktree at
    # all, so offering a way to force past this would be offering something
    # that does not exist.
    if test (path resolve $wt | string collect) = (path resolve $main | string collect)
        _gw_say err "refusing to remove the main worktree: $wt"
        return 1
    end

    # Every question — which remote, which head branch, is this branch finished
    # — is asked of the repository the worktree belongs to, not of the shell's.
    set -l branch ''
    set -l flags ''
    set -l us (printf '\x1f')
    for record in (_gw_records $wt | string split0)
        set -l fields (string split $us -- $record)
        test (path resolve $fields[1] | string collect) = "$wt"; or continue
        set branch $fields[3]
        set flags $fields[4]
        break
    end

    set -l remote (_gw_remote $main)
    # The ref is what every merge question is asked about; the name is what the
    # messages say and what "is it the head branch?" compares against. The
    # remote is stripped literally, not as a regex: a remote may be named with
    # characters a regex reads as operators.
    set -l head_ref (_gw_head_branch "$remote" 0 $main)
    set -l head_name (string replace -r '^refs/(remotes|heads)/' '' -- "$head_ref")
    if test -n "$remote"; and string match --quiet -- "$remote/*" "$head_name"
        set head_name (string replace -- "$remote/" '' "$head_name")
    end

    _gw_clean_refusal $wt "$branch" "$flags" (path resolve $PWD | string collect) $main "$head_name"
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

    # Gitignored files are the one loss nothing here can undo. `git worktree
    # remove` deletes them without --force and without a word, and every
    # refusal above read this checkout as clean because `git status
    # --porcelain` does not report them. So they get their own flag, their own
    # listing and their own question.
    set -l delete_ignored 0
    set -q _flag_delete_ignored; and set delete_ignored 1
    set -l ignored
    test $delete_ignored = 0; and set ignored (_gw_ignored_paths $wt)
    set -l n_ignored (count $ignored)
    set -l ign_word 'ignored paths'
    set -l ign_them them
    if test $n_ignored -eq 1
        set ign_word 'ignored path'
        set ign_them it
    end

    # No terminal is not a licence to guess. --yes would not answer this
    # either: it means "do not stop to ask about anything git could put back",
    # and this is the one thing it could not.
    if test $n_ignored -gt 0; and not isatty stdin
        _gw_say err "not removing $wt — it holds $n_ignored $ign_word and there is no terminal to ask on"
        for p in $ignored
            echo "      $p" >&2
        end
        _gw_say err "  nothing tracks $ign_them and nothing restores $ign_them; pass --delete-ignored if you mean it"
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
        test (path resolve $wt | string collect) != (path resolve $main | string collect)
        and set gitdir (git -C $wt rev-parse --absolute-git-dir 2>/dev/null | string collect)
        if test -n "$gitdir"; and test -d "$gitdir/modules"
            _gw_say err "$wt holds submodule git directories — --force would delete them with it"
            echo "  push the submodules' commits somewhere first, then:" >&2
            echo "    git -C $main worktree remove --force $wt" >&2
            return 1
        end

        # Asked here as well as on the ordinary path. --force overrides the
        # refusal, not the question: `git worktree remove --force` deletes
        # whatever is uncommitted in the checkout, and an unstaged edit was
        # never hashed, so nothing restores it.
        echo "Remove worktree $wt" >&2
        test -n "$branch"
        and echo "  branch $branch — $refusal; it is kept" >&2
        test -n "$refusal"
        and echo "  --force: removing it anyway" >&2

        set -l question 'Proceed?'
        if test $n_ignored -gt 0
            echo "  $n_ignored $ign_word — nothing tracks $ign_them, and nothing restores $ign_them:" >&2
            for p in $ignored
                echo "      $p" >&2
            end
            set question "Delete $n_ignored $ign_word along with the worktree?"
        end
        if not _gw_confirm "$question"
            _gw_say info 'left alone'
            return 1
        end

        if not _gw_run "removing $wt" git -C $main worktree remove --force $wt
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
    set -l question 'Proceed? [y/N] '
    if test $n_ignored -gt 0
        echo "  $n_ignored $ign_word — nothing tracks $ign_them, and nothing restores $ign_them:" >&2
        for p in $ignored
            echo "      $p" >&2
        end
        set question "Delete those $n_ignored $ign_word along with the worktree? [y/N] "
    end
    read --local --prompt-str=$question answer
    if not string match --quiet --regex '^[Yy]' -- "$answer"
        _gw_say info 'left alone'
        return 1
    end

    _gw_remove_one $wt "$branch" "$why"
    set -l rc $status
    _gw_suggest_prune $main
    return $rc
end
