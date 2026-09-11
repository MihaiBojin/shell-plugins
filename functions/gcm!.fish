function gcm! -d 'Go to the default branch and bring it up to date, in one command'
    # The git commands are written out here rather than called through gcm and
    # gup: what this runs is what the line printed first says, and reading one
    # file answers what it does.
    if test "$argv[1]" = -h -o "$argv[1]" = --help
        echo 'gcm!               check out the default branch, then fetch and rebase onto it' >&2
        echo '' >&2
        echo 'gcm followed by gup, as one command. Each step has to succeed before' >&2
        echo 'the next one runs. Takes no arguments.' >&2
        return 0
    end

    if test (count $argv) -gt 0
        _git_alias_say err "gcm! takes no arguments — usage: gcm!"
        return 2
    end

    set -l branch (_git_alias_main_branch)
    if test -z "$branch"
        _git_alias_say err 'not a git repository'
        return 1
    end

    _git_alias_announce "git checkout $branch && git fetch --all --tags --prune --jobs=10 && git pull --rebase"
    git checkout $branch
    and git fetch --all --tags --prune --jobs=10
    and git pull --rebase
end
