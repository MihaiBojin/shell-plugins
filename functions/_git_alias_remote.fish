function _git_alias_remote -d 'The remote this repository belongs to'
    # `origin` is a convention, not a fact: a repository may have one remote
    # called something else, or several with no obvious winner. Ask git's own
    # configuration rather than introduce a setting of this plugin's own —
    # every rung below is a key git already defines and most clones already
    # set, so a repository answers this without anybody typing anything.
    #
    # remote.pushDefault is deliberately absent. It names where commits go, not
    # where they come from, and the two differ in exactly the case that makes
    # this question worth asking: a fork you push to, an upstream you branch
    # from. _git_alias_push_remote reads it instead.
    #
    set -l remotes (git remote 2>/dev/null)
    set -q remotes[1]; or return 1
    if test (count $remotes) -eq 1
        echo $remotes[1]
        return 0
    end

    set -l stated
    # git's own knob for this exact ambiguity.
    set -l value (git config --get checkout.defaultRemote 2>/dev/null)
    test -n "$value"; and set -a stated $value
    # Where the current branch came from. Every clone sets it, which is why it
    # comes second: it answers a narrower question, but it still beats a guess.
    set -l branch (git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -n "$branch"
        set value (git config --get branch.$branch.remote 2>/dev/null)
        test -n "$value"; and set -a stated $value
    end

    for candidate in $stated
        test -n "$candidate" -a "$candidate" != .; or continue
        contains -- $candidate $remotes; and echo $candidate; and return 0
    end

    contains -- origin $remotes; and echo origin; and return 0
    echo $remotes[1]
end
