# gwr [PATH|QUERY].
complete -c gwr -f
complete -c gwr -s h -l help -d 'show usage'
complete -c gwr -s f -l force \
    -d 'remove it even when the branch is unfinished; the branch is kept'
complete -c gwr -l delete-ignored \
    -d 'also delete the gitignored files in it; nothing restores them'
complete -c gwr -l no-forge -d 'decide from git alone; never ask GitHub/GitLab'
complete -c gwr -s y -l yes -d 'do not ask before removing; ignored files still ask'
complete -c gwr -a '(_gw_complete_worktrees)'
