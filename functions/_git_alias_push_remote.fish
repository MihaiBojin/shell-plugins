function _git_alias_push_remote -d 'The remote a push goes to'
    # remote.pushDefault is git's answer to "where do my commits go", and it is
    # the whole reason a fork checkout works: branch from upstream, push to the
    # fork. Nothing here writes it — this only checks whether it is set, and
    # falls back to the remote the repository belongs to when it is not.
    set -l value (git config --get remote.pushDefault 2>/dev/null)
    if test -n "$value"; and git remote get-url $value >/dev/null 2>&1
        echo $value
        return 0
    end
    _git_alias_remote
end
