function _gw_head_branch -a remote online repo -d 'The full ref this repository branches from, e.g. refs/remotes/origin/main'
    # The ladder is the same one the Zsh plugin climbs, rung for rung, so both
    # shells decide the head branch the same way on the same repository. What
    # Fish leaves out is rung 3: Zsh stops to offer a list, and nothing here
    # asks.
    #
    # The answer is a full ref, never `origin/main`. It is used as a revision by
    # every merge question gwr asks, and a bare name is resolved as a tag first
    # — see _gw_full_ref.
    test -n "$repo"; or set repo $PWD

    # 1. The repository's own answer, refreshed from the server if allowed.
    #    Recorded at clone time from what the server advertises, so it tells
    #    master from main without guessing. Ignored when it dangles, which is
    #    what a server-side rename leaves behind.
    if test -n "$remote"
        set -l symref (git -C $repo symbolic-ref --quiet refs/remotes/$remote/HEAD 2>/dev/null)
        if test -n "$symref"; and git -C $repo show-ref --verify --quiet $symref
            echo $symref
            return 0
        end

        # set-head can only point at a remote-tracking ref, so don't spend a
        # round trip (or print its error) when the repository has none.
        # `test -n (cmd)` with no output is `test -n`, which is true. So the
        # answer goes through a variable.
        set -l tracking (git -C $repo for-each-ref --count=1 --format='%(refname)' refs/remotes/$remote 2>/dev/null)
        if test "$online" = 1; and set -q tracking[1]
            if _gw_run "asking $remote for its default branch" git -C $repo remote set-head $remote --auto
                set symref (git -C $repo symbolic-ref --quiet refs/remotes/$remote/HEAD 2>/dev/null)
                if test -n "$symref"; and git -C $repo show-ref --verify --quiet $symref
                    echo $symref
                    return 0
                end
            end
        end
    end

    # 2. Conventional names — decisive only when exactly one of them exists.
    #    Remote-tracking first, then local heads: a repository can have a remote
    #    and still no refs/remotes at all — a remote added by hand has never
    #    been fetched.
    set -l found
    if test -n "$remote"
        for candidate in main master trunk
            git -C $repo show-ref --verify --quiet refs/remotes/$remote/$candidate
            and set -a found $remote/$candidate
        end
    end
    if not set -q found[1]
        for candidate in main master trunk
            git -C $repo show-ref --verify --quiet refs/heads/$candidate
            and set -a found $candidate
        end
    end
    if test (count $found) -eq 1
        _gw_full_ref $found[1] $repo
        return 0
    end

    # 3. Zsh asks here. Fish does not.
    #
    # 4. Guess, and be honest that it is one.
    set -q found[1]; or return 1
    if test (count $found) -gt 1
        set -l msg ''
        test -n "$remote"; and set msg "$remote/HEAD is unset and "
        set msg "$msg"(string join ', ' $found)" all exist — guessing $found[1]"
        test -n "$remote"
        and set msg "$msg; settle it with: git -C $repo remote set-head $remote --auto"
        _gw_say warn "$msg"
    end
    _gw_full_ref $found[1] $repo
end
