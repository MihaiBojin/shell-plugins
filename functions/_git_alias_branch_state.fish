function _git_alias_branch_state -a branch -d 'Say what deleting $branch would cost'
    # Prints one line of reasoning either way. The exit status is the verdict:
    # 0 the commits survive somewhere else, 1 this name is the only handle on
    # them.
    set -l head (_git_alias_main_branch)

    if git merge-base --is-ancestor refs/heads/$branch refs/heads/$head 2>/dev/null
        echo "merged into $head"
        return 0
    end

    # Most branches end in a squash, which rewrites their commits into one, so
    # git sees a branch whose commits appear nowhere upstream — the same shape
    # as a branch nobody ever merged. Ask a different question: replay the tree
    # as a single commit on the merge base and let `git cherry` compare content
    # rather than history, which is what a squash preserves.
    set -l base (git merge-base refs/heads/$head refs/heads/$branch 2>/dev/null)
    set -l tree (git rev-parse refs/heads/$branch\^\{tree\} 2>/dev/null)
    if test -n "$base" -a -n "$tree"
        # commit-tree fails outright when user.email is unset, so the identity
        # is pinned. Nothing references the commit; the next gc collects it.
        set -l synth (env GIT_AUTHOR_NAME=git-alias GIT_AUTHOR_EMAIL=git-alias@localhost GIT_AUTHOR_DATE='@0 +0000' \
            GIT_COMMITTER_NAME=git-alias GIT_COMMITTER_EMAIL=git-alias@localhost GIT_COMMITTER_DATE='@0 +0000' \
            git commit-tree $tree -p $base -m _ 2>/dev/null)
        if test -n "$synth"
            # A leading '-' means the patch is already upstream.
            set -l verdict (git cherry refs/heads/$head $synth 2>/dev/null)
            if set -q verdict[1]; and string match --quiet -- '-*' $verdict[1]
                echo "squash-merged into $head"
                return 0
            end
        end

        # A branch that leaves the head branch's tree exactly as it found it
        # has nothing left to contribute, whatever its history says.
        set -l head_tree (git rev-parse refs/heads/$head\^\{tree\} 2>/dev/null)
        if test -n "$head_tree" -a "$tree" = "$head_tree"
            echo "leaves $head's tree exactly as it found it"
            return 0
        end
    end

    # Another ref at the same commit: the name goes, the commits stay reachable
    # under the other one. A pushed branch usually lands here, through its
    # remote-tracking ref.
    set -l sha (git rev-parse --verify --quiet refs/heads/$branch)
    if test -n "$sha"
        for twin in (git for-each-ref --format='%(refname:short)' --points-at $sha refs/heads refs/remotes)
            test "$twin" = "$branch"; and continue
            echo "same commit as $twin"
            return 0
        end
    end

    echo "not in $head: no merge, no squash, no other ref at its commit"
    return 1
end
