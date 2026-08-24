function _gw_sweep -a go use_forge only_branch -d 'Remove every finished worktree of this repository'
    # Same predicate and same refusals as a plain gwr; the difference is that
    # nothing stops to ask about each worktree. So it does nothing until asked
    # twice: the plain run is a dry run, and the dry run is the confirmation.
    if not git rev-parse --git-dir >/dev/null 2>&1
        _gw_say err 'not inside a git repository'
        return 1
    end

    set -l main (_gw_main_worktree); or return 1
    set -l remote (_gw_remote $main)
    set -l head_ref (_gw_head_branch "$remote" 0 $main)
    set -l head_name (string replace -r "^$remote/" '' -- "$head_ref")
    if test -z "$head_ref"
        _gw_say err "cannot work out this repository's head branch"
        _gw_say err "  record it with: git -C $main remote set-head $remote --auto"
        return 1
    end

    set -l cwd (path resolve $PWD)
    set -l removed 0
    set -l kept 0

    for record in (_gw_records)
        set -l fields (string split \t -- $record)
        set -l wt $fields[1]
        set -l branch $fields[3]
        set -l flags $fields[4]

        if test -n "$only_branch"; and test "$branch" != "$only_branch"
            continue
        end

        set -l label $branch
        test -n "$label"; or set label (path basename $wt)

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

    if test "$go" = 1
        _gw_say info "$removed removed, $kept left alone"
        _gw_suggest_prune $main
    else
        _gw_say info "$removed to remove, $kept left alone — re-run with --yes to do it"
    end
    return 0
end
