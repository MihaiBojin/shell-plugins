function gup -d 'Fetch everything, prune what the remote dropped, then rebase onto it'
    if test "$argv[1]" = -h -o "$argv[1]" = --help
        echo 'gup [ARGS...]      fetch all remotes, prune, then pull --rebase' >&2
        echo '' >&2
        echo 'The fetch has to succeed before the pull runs. Any arguments go to the' >&2
        echo 'pull, as they did when this was an abbreviation.' >&2
        return 0
    end

    _git_alias_announce 'git fetch --all --tags --prune --jobs=10 &&' git pull --rebase $argv
    git fetch --all --tags --prune --jobs=10
    and git pull --rebase $argv
end
