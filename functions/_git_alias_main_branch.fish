function _git_alias_main_branch -a remote -d 'What this repository calls its default branch'
    # Used by gcm, gmom and gnb. `main` and `master` are both common enough that
    # guessing is wrong often enough to notice, so ask the repository first: git
    # records the answer in <remote>/HEAD at clone time, from what the server
    # advertised.
    #
    # Every remote carries its own, and they differ — a fork's origin can say
    # main while the upstream it was forked from says develop. So the remote is
    # resolved rather than assumed, and a caller that already knows which one it
    # means passes it in.
    #
    # Deliberately not shared with the git-worktree commands' _gw_head_branch,
    # which does the same job more thoroughly and can go to the network. Each
    # feature here works when it is the only one installed.
    git rev-parse --git-dir >/dev/null 2>&1; or return 1

    test -n "$remote"; or set remote (_git_alias_remote)

    # The resolved remote first, then any other, so a repository whose origin
    # never had its HEAD recorded still gets an advertised answer rather than a
    # guess.
    for candidate in $remote (git remote 2>/dev/null)
        test -n "$candidate"; or continue
        set -l ref (git symbolic-ref --quiet --short refs/remotes/$candidate/HEAD 2>/dev/null)
        if test -n "$ref"
            string replace -- "$candidate/" '' $ref
            return 0
        end
    end

    for branch in main trunk master
        if git show-ref --verify --quiet refs/heads/$branch 2>/dev/null
            echo $branch
            return 0
        end
    end

    # Nothing said so. `main` is the likelier guess and the caller sees it fail.
    echo main
    return 1
end
