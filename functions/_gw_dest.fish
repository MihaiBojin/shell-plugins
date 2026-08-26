function _gw_dest -a name -d 'Where a worktree for branch $name would live'
    # <root>/<NAME>/<REPO>, with NAME the branch as written, slashes and all:
    # `fix/login` nests at <root>/fix/login/<REPO>. Directory name equals branch
    # name is the invariant every tool writing into this root keeps.
    #
    # <REPO> is the checkout's directory name exactly as git left it, a trailing
    # `.git` included. Trimming it would put a worktree somewhere the companion
    # `origin` CLI does not look, and finding each other's worktrees is the
    # whole point of deriving this path rather than configuring it.
    set -l main (_gw_main_worktree); or return 1
    set -l root (_gw_wt_dir $main); or return 1
    echo $root/$name/(path basename $main)
end
