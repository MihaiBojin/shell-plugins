function _git_alias_main_branch -d 'What this repository calls its default branch'
    # Used by gcm and gmom. `main` and `master` are both common enough that
    # guessing is wrong often enough to notice, so ask the repository first: git
    # records the answer in <remote>/HEAD at clone time, from what the server
    # advertised.
    #
    # Deliberately not shared with the git-worktree commands' _gw_head_branch,
    # which does the same job more thoroughly and can go to the network. Each
    # feature here works when it is the only one installed.
    git rev-parse --git-dir >/dev/null 2>&1; or return 1

    for remote in origin upstream
        set -l ref (git symbolic-ref --quiet --short refs/remotes/$remote/HEAD 2>/dev/null)
        or continue
        string replace -- "$remote/" '' $ref
        return 0
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
