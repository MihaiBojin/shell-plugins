function _gw_head_branch -a remote online repo -d 'The ref this repository branches from, e.g. origin/main'
    # In decreasing order of how deliberate the answer is. Unlike the Zsh
    # plugin, nothing here asks: a Fish command that cannot work the head branch
    # out says so and names the one command that records it, rather than
    # stopping mid-run to offer a list.
    test -n "$repo"; or set repo $PWD

    set -l stated (git -C $repo config --get git-worktree-plugin.headBranch 2>/dev/null)
    if test -n "$stated"
        if test -n "$remote"; and git -C $repo show-ref --verify --quiet refs/remotes/$remote/$stated
            echo $remote/$stated
        else
            echo $stated
        end
        return 0
    end

    if test -n "$remote"
        # Recorded at clone time from what the server advertises. This is the
        # real answer, and it is what tells master from main without guessing.
        # Ignored when it dangles, which is what a server-side rename leaves.
        set -l symref (git -C $repo symbolic-ref --quiet refs/remotes/$remote/HEAD 2>/dev/null)
        if test -n "$symref"; and git -C $repo show-ref --verify --quiet $symref
            echo (string replace 'refs/remotes/' '' -- $symref)
            return 0
        end

        if test "$online" = 1
            # Missing or stale: re-ask the server and cache the answer, so git
            # and every other tool benefit and nothing asks again.
            if git -C $repo remote set-head $remote --auto >/dev/null 2>&1
                set symref (git -C $repo symbolic-ref --quiet refs/remotes/$remote/HEAD 2>/dev/null)
                if test -n "$symref"
                    echo (string replace 'refs/remotes/' '' -- $symref)
                    return 0
                end
            end
        end
    end

    set -l found
    for candidate in main master trunk
        git -C $repo show-ref --verify --quiet refs/heads/$candidate; and set -a found $candidate
    end
    if test (count $found) -eq 1
        echo $found[1]
        return 0
    end

    return 1
end
