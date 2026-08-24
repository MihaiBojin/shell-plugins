function _gw_stashes_for -a branch repo -d 'How many stash entries are parked on $branch'
    # The repository has to be named: gwr is given a path and can be standing
    # anywhere, and `git stash list` in the wrong repository answers about the
    # wrong stashes — or fails and answers zero, which reads as "nothing parked".
    #
    # Compared case-insensitively rather than by glob: git writes "WIP on
    # <branch>:" for a plain stash and "On <branch>:" for one given a message,
    # and a branch name is not a pattern.
    test -n "$repo"; or set repo $PWD
    set -l needle "on "(string lower -- $branch)":"
    set -l n 0
    for line in (git -C $repo stash list 2>/dev/null)
        string match --quiet -- "*$needle*" (string lower -- $line); and set n (math $n + 1)
    end
    echo $n
end
