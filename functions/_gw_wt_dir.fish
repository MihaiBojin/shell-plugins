function _gw_wt_dir -a dir -d 'The root this repository keeps its worktrees under'
    # `.worktrees` beside the main checkout, and nothing configures it. Deriving
    # it from the repository's own location means a fresh clone needs no setup,
    # and the Zsh plugin and the companion `origin` plugin derive the same path
    # the same way — three tools cannot disagree about a location none of them
    # can be told.
    set -l main (_gw_main_worktree $dir); or return 1
    echo (path dirname $main)/.worktrees
end
