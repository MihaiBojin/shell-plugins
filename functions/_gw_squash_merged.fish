function _gw_squash_merged -a branch head_ref repo -d 'Is the change branch $branch makes already in $head_ref?'
    # `git branch --merged` answers for the merge git can see. Most branches now
    # end in a squash, which rewrites their commits into one, so git sees a
    # branch whose commits appear nowhere in the head branch — the same shape as
    # a branch nobody ever merged. Reaping on that reading loses work; refusing
    # on it means never reaping anything.
    #
    # So ask a different question. Replay the branch's tree as a single commit on
    # top of the merge base and let `git cherry` say whether that patch is
    # already upstream: it compares content rather than history, which is what a
    # squash preserves.
    test -n "$repo"; or set repo $PWD

    set -l base (git -C $repo merge-base $head_ref refs/heads/$branch 2>/dev/null); or return 1
    test -n "$base"; or return 1
    set -l tree (git -C $repo rev-parse refs/heads/$branch^{tree} 2>/dev/null); or return 1
    test -n "$tree"; or return 1

    # A branch that leaves the head branch's tree exactly as it found it has
    # nothing left to contribute, whatever its history says.
    set -l head_tree (git -C $repo rev-parse $head_ref^{tree} 2>/dev/null)
    test -n "$head_tree" -a "$tree" = "$head_tree"; and return 0

    # The identity has to be pinned: commit-tree fails outright when user.email
    # is unset, and a fixed one keeps the synthetic commit reproducible. Nothing
    # references it, so the next gc collects it.
    set -l synth (env GIT_AUTHOR_NAME=gw GIT_AUTHOR_EMAIL=gw@localhost GIT_AUTHOR_DATE='@0 +0000' \
        GIT_COMMITTER_NAME=gw GIT_COMMITTER_EMAIL=gw@localhost GIT_COMMITTER_DATE='@0 +0000' \
        git -C $repo commit-tree $tree -p $base -m _ 2>/dev/null); or return 1
    test -n "$synth"; or return 1

    # A leading '-' means the patch is already upstream; '+' means it is not.
    set -l verdict (git -C $repo cherry $head_ref $synth 2>/dev/null); or return 1
    string match --quiet -- '-*' $verdict[1]
end
