function _gw_remote -a repo -d 'The remote this repository belongs to'
    # `origin` is a convention, not a fact: a repository may have one remote
    # called something else, or several with no obvious winner. Ask the
    # repository what it thinks, in decreasing order of how deliberate the
    # answer is, and fall back to a name rather than to a question — Fish's
    # commands here are never the interactive half of the Zsh plugin.
    #
    # git-worktree-plugin.remote is the shared key: the Zsh plugin and the
    # companion `origin` plugin read the same one, so a repository answers this
    # once for all three.
    #
    # remote.pushDefault is not a rung. It names where commits go, not where
    # they come from, and the two differ in exactly the case that makes this
    # question worth asking: a fork you push to, an upstream you branch from.
    test -n "$repo"; or set repo $PWD

    set -l remotes (git -C $repo remote 2>/dev/null)
    set -q remotes[1]; or return 1
    if test (count $remotes) -eq 1
        echo $remotes[1]
        return 0
    end

    set -l stated
    set -q git_worktree_remote; and set -a stated $git_worktree_remote
    for key in git-worktree-plugin.remote checkout.defaultRemote
        set -l value (git -C $repo config --get $key 2>/dev/null)
        test -n "$value"; and set -a stated $value
    end
    set -l branch (git -C $repo symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -n "$branch"
        set -l value (git -C $repo config --get branch.$branch.remote 2>/dev/null)
        test -n "$value"; and set -a stated $value
    end

    for candidate in $stated
        test -n "$candidate" -a "$candidate" != .; or continue
        contains -- $candidate $remotes; and echo $candidate; and return 0
    end

    contains -- origin $remotes; and echo origin; and return 0
    echo $remotes[1]
end
