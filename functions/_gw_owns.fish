function _gw_owns -a candidate -d 'Does this repository own the worktree at $candidate?'
    # Returns 0 when it does, or when there is no repository there at all.
    # Returns 1 and leaves the owning repository in $_gw_reply when somebody
    # else does.
    #
    # git is what answers this. `git worktree list` cannot: a worktree belonging
    # to another repository is one this repository has never heard of, so the
    # list comes back empty and reads exactly like "nothing is there" — which is
    # how a `gwa` that should have refused ends up cd-ing you into somebody
    # else's checkout instead.
    set -g _gw_reply ''

    set -l theirs (git -C $candidate rev-parse --path-format=absolute --git-common-dir 2>/dev/null); or return 0
    test -n "$theirs"; or return 0
    # No -C: gwa runs inside the repository, and from a worktree of it this
    # still resolves to the repository's own common dir, which is the point.
    set -l ours (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); or return 0
    test -n "$ours"; or return 0

    test (path resolve $theirs) = (path resolve $ours); and return 0

    set -g _gw_reply (path dirname (path resolve $theirs))
    return 1
end
