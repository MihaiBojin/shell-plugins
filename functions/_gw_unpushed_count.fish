function _gw_unpushed_count -a branch repo -d 'Commits on $branch its upstream has not got'
    # Returns 1 and prints nothing when the branch has no upstream: the answer
    # is then unknown, not zero. gwa creates branches with --no-track, so "no
    # upstream" is the normal state for the branches this plugin makes, and
    # reporting zero would quietly disarm the guard for exactly those.
    test -n "$repo"; or set repo $PWD
    set -l upstream (git -C $repo rev-parse --abbrev-ref --symbolic-full-name $branch'@{upstream}' 2>/dev/null); or return 1
    test -n "$upstream"; or return 1
    set -l count (git -C $repo rev-list --count $upstream..refs/heads/$branch 2>/dev/null); or return 1
    echo $count
end
