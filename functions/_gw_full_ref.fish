function _gw_full_ref -a name repo -d 'The full ref naming head branch $name'
    # A bare name used as a revision is resolved by git as a tag before anything
    # else, so a tag called `origin/main` is what `origin/main` means to
    # `merge-base`, `cherry` and `^{tree}`. Point that tag at a commit that
    # contains an unmerged branch and the branch reads as merged — a deleted
    # branch, at rc 0, with nothing to say it happened.
    #
    # So the head branch travels as a ref that can only mean a branch.
    # Remote-tracking first, because that is what the head branch normally is; a
    # name with no remote-tracking ref is spelled under refs/heads/ whether or
    # not it exists, because a name that resolves to nothing is a better answer
    # than a name that resolves to a tag.
    test -n "$name"; or return 1
    test -n "$repo"; or set repo $PWD

    if git -C $repo show-ref --verify --quiet refs/remotes/$name 2>/dev/null
        echo refs/remotes/$name
    else
        echo refs/heads/$name
    end
end
