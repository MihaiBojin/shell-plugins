function _git_alias_push_remote -d 'The remote a push goes to'
    # git's own precedence, from git-config(1): branch.<name>.pushRemote
    # overrides remote.pushDefault, which overrides branch.<name>.remote. This
    # is not a policy of this plugin's — it is the order git itself uses to pick
    # a push target, and it exists so that "pull from upstream, push to my fork"
    # works. Nothing here writes any of it.
    #
    # Falling through to _git_alias_remote covers the rest, single-remote
    # repositories included: with one remote, that is where a push goes.
    set -l branch (git symbolic-ref --quiet --short HEAD 2>/dev/null)
    set -l keys
    test -n "$branch"; and set -a keys "branch.$branch.pushRemote"
    set -a keys remote.pushDefault

    for key in $keys
        set -l value (git config --get $key 2>/dev/null)
        if test -n "$value"; and git remote get-url $value >/dev/null 2>&1
            echo $value
            return 0
        end
    end
    _git_alias_remote
end
