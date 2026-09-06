function _gw_sweep -a go use_forge only_branch online delete_ignored -d 'Remove every finished worktree of this repository'
    # Same predicate and same refusals as a plain gwr; the difference is that
    # nothing stops to ask about each worktree. So it does nothing until asked
    # twice: the plain run is a dry run, and the dry run is the confirmation.
    if not git rev-parse --git-dir >/dev/null 2>&1
        _gw_say err 'not inside a git repository'
        return 1
    end

    set -l main (_gw_main_worktree | string collect); or return 1
    set -l remote (_gw_remote $main)
    set -l head_ref (_gw_head_branch "$remote" $online $main)
    if test -z "$head_ref"
        _gw_say err "cannot work out this repository's head branch"
        _gw_say err "  record it with: git -C $main remote set-head $remote --auto"
        return 1
    end

    # refs/remotes/origin/main is the revision every merge question is asked
    # about; origin/main is what the messages say; main is the branch name the
    # refusals compare against.
    set -l head_disp (string replace -r '^refs/(remotes|heads)/' '' -- "$head_ref")
    set -l head_name $head_disp
    if test -n "$remote"; and string match --quiet -- "$remote/*" "$head_disp"
        set head_name (string replace -- "$remote/" '' "$head_disp")
    end

    # Every branch here is judged against the head branch, so a stale local copy
    # of it keeps branches the remote has already taken. One fetch for the whole
    # run, rather than one per worktree. A remote that cannot be reached is not
    # fatal — the local copy still answers, it just answers about yesterday.
    if test "$online" = 1; and test -n "$remote"; and string match --quiet -- "refs/remotes/$remote/*" "$head_ref"
        _gw_run "fetching $head_disp" git -C $main fetch --quiet $remote $head_name
        or _gw_say warn "using the local copy of $head_disp"
    end

    set -l cwd (path resolve $PWD | string collect)
    set -l removed 0
    set -l kept 0
    set -l considered 0

    set -l us (printf '\x1f')
    for record in (_gw_records | string split0)
        set -l fields (string split $us -- $record)
        set -l wt $fields[1]
        set -l branch $fields[3]
        set -l flags $fields[4]

        if test -n "$only_branch"; and test "$branch" != "$only_branch"
            continue
        end
        set considered (math $considered + 1)

        set -l label $branch
        test -n "$label"; or set label (path basename $wt | string collect)

        _gw_clean_refusal $wt "$branch" "$flags" $cwd $main "$head_name"
        if test -n "$_gw_reply"
            printf '  %-12s %s — %s\n' skip $label $_gw_reply >&2
            set kept (math $kept + 1)
            continue
        end

        if not _gw_is_finished "$branch" "$head_ref" "$head_name" $use_forge $main
            printf '  %-12s %s — %s\n' skip $label $_gw_reply >&2
            set kept (math $kept + 1)
            continue
        end
        set -l why $_gw_reply

        # Asked here rather than in _gw_clean_refusal, which is also gwr's own
        # refusal: this one is conditional on a flag, and a shared refusal that
        # reads a flag it was not given would skip every worktree holding a
        # node_modules/.
        #
        # The sweep never prompts, so a worktree with gitignored files in it is
        # left alone until --delete-ignored says otherwise — and the dry run
        # says so, rather than promising a removal that would then refuse.
        if test "$delete_ignored" != 1
            set -l ignored (_gw_ignored_paths $wt)
            set -l n (count $ignored)
            if test $n -gt 0
                # The names, not just the count: .env and node_modules/ deserve
                # different answers, and this line is the only place the sweep
                # says which it found.
                set -l shown (string join ', ' $ignored[1..(math min 3,$n)])
                test $n -gt 3; and set shown "$shown, …"
                set -l word 'ignored paths'
                test $n -eq 1; and set word 'ignored path'
                printf '  %-12s %s — holds %d %s (%s) — --delete-ignored deletes them\n' \
                    skip $label $n $word $shown >&2
                set kept (math $kept + 1)
                continue
            end
        end

        if test "$go" = 1
            if _gw_remove_one $wt "$branch" "$why"
                set removed (math $removed + 1)
            else
                set kept (math $kept + 1)
            end
        else
            printf '  %-12s %s — %s\n' 'would remove' $label $why >&2
            set removed (math $removed + 1)
        end
    end

    # A --branch nobody has checked out is a typo, not an empty sweep: saying
    # "0 to remove" and exiting 0 would let a script think it had done the job.
    if test "$considered" -eq 0; and test -n "$only_branch"
        _gw_say err "no worktree of this repository has branch '$only_branch' checked out"
        return 1
    end

    if test "$go" = 1
        _gw_say info "$removed removed, $kept left alone"
        _gw_suggest_prune $main
    else
        _gw_say info "$removed to remove, $kept left alone — re-run with --yes to do it"
    end
    return 0
end
