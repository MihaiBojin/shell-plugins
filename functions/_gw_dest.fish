function _gw_dest -a name -d 'Where a worktree for branch $name would live'
    # <root>/<NAME>/<REPO>, with NAME the branch as written, slashes and all:
    # `fix/login` nests at <root>/fix/login/<REPO>. Directory name equals branch
    # name is the invariant every tool writing into this root keeps.
    set -l main (_gw_main_worktree); or return 1
    set -l root (_gw_wt_dir $main); or return 1
    set -l repo (string replace -r '\.git$' '' -- (path basename $main))
    echo $root/$name/$repo
end
