function gcm -d 'Check out whatever this repository calls its default branch'
    if test "$argv[1]" = -h -o "$argv[1]" = --help
        echo 'gcm [ARGS...]      check out the default branch' >&2
        echo '' >&2
        echo 'The branch is asked for at the moment you run this, not guessed, and' >&2
        echo 'the line printed first names the one it reached. Any arguments follow' >&2
        echo 'the branch name, as they did when this was an abbreviation.' >&2
        return 0
    end

    # A non-zero status here means the answer is a guess rather than an
    # advertised head, which is git's to refuse: the abbreviation this replaced
    # ran it either way.
    set -l branch (_git_alias_main_branch)
    if test -z "$branch"
        _git_alias_say err 'not a git repository'
        return 1
    end

    _git_alias_announce git checkout $branch $argv
    git checkout $branch $argv
end
