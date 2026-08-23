function gunwipall --description 'Undo every recent --wip-- commit, not just the last one'
    # `gunwip` resets exactly one commit. This resets to the newest commit
    # whose subject is *not* a `--wip--`, dropping the whole run of them at
    # once. The changes stay in the working tree — a mixed reset, like
    # gunwip's.
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gunwipall: not inside a git repository" >&2
        return 1
    end

    # Walked by hand rather than with --grep --invert-grep, which matches the
    # whole commit message: a real commit whose body mentions --wip-- would be
    # taken for a wip and reset past, losing it. --first-parent because a wip
    # commit can itself be a merge, and a plain walk would cross into the
    # merged-in branch.
    set -l commit
    for line in (git log --first-parent --format='%H %s')
        set -l subject (string split --max 1 ' ' -- $line)[2]
        if not string match --quiet -- '*--wip--*' "$subject"
            set commit (string split --max 1 ' ' -- $line)[1]
            break
        end
    end

    # No non-wip commit anywhere in the history: resetting to an empty revision
    # would silently turn into a bare `git reset`, which unstages everything.
    if test -z "$commit"
        echo "gunwipall: every commit is a --wip-- — nothing to reset onto" >&2
        return 1
    end

    if test "$commit" = (git rev-parse HEAD)
        return 0
    end

    git reset $commit
end
