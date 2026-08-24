function _gw_is_finished -a branch head_ref head_name use_forge repo -d 'Is $branch finished with respect to $head_ref?'
    # The one predicate: gwr asks it about the branch you named, --all asks it
    # about every branch it walks, and they differ in nothing else. $_gw_reply is
    # the reason either way, phrased to be read after "branch <name> —".
    #
    # Three ways to qualify, in this order: git can see the merge; the change is
    # already upstream although git cannot see it (a squash); or the forge says
    # the request was merged or closed. Only the third needs the network, and
    # only the third can be wrong about work pushed after the merge — hence the
    # count.
    test -n "$repo"; or set repo $PWD
    set -g _gw_reply ''

    if _gw_merged_reason $branch $head_ref $repo
        set -g _gw_reply "$_gw_reply into $head_name"
        return 0
    end

    if test "$use_forge" = 1; and _gw_forge_state $branch $repo
        set -l fields (string split \t -- $_gw_reply)
        set -l state $fields[1]
        set -l number $fields[2]
        set -l noun request
        set -q _gw_forge_noun; and set noun $_gw_forge_noun
        if contains -- $state MERGED CLOSED
            set -l lower (string lower -- $state)
            # No upstream means the answer is unknown, not zero — and gwa makes
            # branches with --no-track, so unknown is the normal case. A request
            # that says "merged" cannot speak for commits nobody has pushed.
            set -l unpushed (_gw_unpushed_count $branch $repo)
            if test $status -ne 0
                set -g _gw_reply "its $noun is $lower, but the branch has no upstream to have been pushed to"
                return 1
            end
            if test "$unpushed" -eq 1
                set -g _gw_reply "its $noun is $lower, but one commit here is not in it"
                return 1
            else if test "$unpushed" -gt 1
                set -g _gw_reply "its $noun is $lower, but $unpushed commits here are not in it"
                return 1
            end
            set -g _gw_reply "its $noun #$number is $lower"
            return 0
        end
    end

    set -g _gw_reply "not merged into $head_name"
    return 1
end
