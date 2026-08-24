function _gw_prune_upto -a wt main -d 'Remove the directories that removing $wt left empty'
    # Up to and including the worktrees root, and never past it: rmdir refuses a
    # directory with anything in it, which is the whole guard.
    set -l root (_gw_wt_dir $main); or return 0
    set -l dir (path dirname $wt)
    while string match --quiet -- "$root/*" $dir; or test "$dir" = "$root"
        rmdir $dir 2>/dev/null; or break
        test "$dir" = "$root"; and break
        set dir (path dirname $dir)
    end
    return 0
end
