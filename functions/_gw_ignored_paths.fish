function _gw_ignored_paths -a wt -d 'The gitignored paths inside $wt'
    # `git status --porcelain` does not mention these, which is why every
    # refusal that asks it reads a checkout holding .env and node_modules/ as
    # clean — and `git worktree remove` then deletes them, at rc 0, without
    # --force and without a word. Nothing in git brings them back: no ref ever
    # pointed at them.
    #
    # --ignored=traditional collapses an ignored directory into one entry, so
    # node_modules/ is one line rather than forty thousand.
    test -n "$wt"; or return 0
    git -C $wt status --porcelain --ignored=traditional 2>/dev/null \
        | string replace --filter --regex '^!! ' ''
end
