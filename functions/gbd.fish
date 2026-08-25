function gbd -d 'Delete branches, having said first what each one would cost'
    argparse h/help f/force -- $argv
    or return 2

    if set -q _flag_help
        echo 'gbd [QUERY]       pick branches to delete — Tab marks more than one' >&2
        echo 'gbd --force       delete without the confirmation prompt' >&2
        echo '' >&2
        echo 'Every branch is reported before anything is deleted: merged, squash-' >&2
        echo 'merged, or held by another ref means the commits survive the deletion.' >&2
        echo 'Anything else is called out, and the prompt says how many. The current' >&2
        echo 'branch and the default branch are always skipped. Each deletion prints' >&2
        echo 'the command that puts the branch back.' >&2
        return 0
    end

    if test (count $argv) -gt 1
        _git_alias_say err 'too many arguments — usage: gbd [QUERY]'
        return 2
    end

    set -l chosen (_git_alias_branch_pick 'delete>' "$argv[1]" multi); or return 1

    set -l current (_git_alias_current_branch)
    set -l head (_git_alias_main_branch)
    set -l doomed
    set -l risky 0

    for branch in $chosen
        if test "$branch" = "$current"
            _git_alias_say warn "$branch is checked out here — skipping"
            continue
        end
        if test "$branch" = "$head"
            _git_alias_say warn "$branch is this repository's default branch — skipping"
            continue
        end
        set -l reason (_git_alias_branch_state $branch)
        set -l safe $status
        set -a doomed $branch
        if test $safe -eq 0
            printf '  %-34s %s\n' $branch $reason
        else
            set risky (math $risky + 1)
            printf '  %-34s %s%s%s\n' $branch (set_color yellow) $reason (set_color normal)
        end
    end

    if not set -q doomed[1]
        _git_alias_say err 'nothing left to delete'
        return 1
    end

    if not set -q _flag_force
        set -l question "Delete "(count $doomed)" branches?"
        test $risky -gt 0; and set question "Delete "(count $doomed)" branches, $risky of them not in $head?"
        read --local --prompt-str="$question [y/N] " answer
        if not string match --quiet --regex '^[Yy]' -- "$answer"
            _git_alias_say warn 'nothing deleted'
            return 1
        end
    end

    # -D rather than -d: the checks above already answered the question -d
    # asks, and -d refuses a squash-merged branch that is provably redundant.
    # The sha goes out with every deletion so the branch can be put back.
    set -l failed 0
    for branch in $doomed
        set -l sha (git rev-parse --verify --quiet refs/heads/$branch)
        if git branch -D $branch >/dev/null 2>&1
            printf '  %-34s deleted — restore with: git branch %s %s\n' $branch $branch (string sub -l 12 -- $sha)
        else
            _git_alias_say err "could not delete $branch"
            set failed 1
        end
    end
    return $failed
end
