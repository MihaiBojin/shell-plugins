function _gw_merged_reason -a branch head_ref repo -d 'Is $branch merged into $head_ref, and how?'
    # Leaves `merged` or `squash-merged` in $_gw_reply and returns 0.
    #
    # refs/heads/ explicitly: a branch name used as a revision is resolved as a
    # tag first, so a tag and a branch sharing a name would answer about the tag.
    test -n "$repo"; or set repo $PWD
    set -g _gw_reply ''

    if git -C $repo merge-base --is-ancestor refs/heads/$branch $head_ref 2>/dev/null
        set -g _gw_reply merged
        return 0
    end
    if _gw_squash_merged $branch $head_ref $repo
        set -g _gw_reply squash-merged
        return 0
    end
    return 1
end
