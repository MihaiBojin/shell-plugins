# gwr [PATH|QUERY] and gwr --all.
complete -c gwr -f
complete -c gwr -s h -l help -d 'show usage'
complete -c gwr -s f -l force -n 'not __fish_seen_argument -l all' \
    -d 'remove it even when the branch is unfinished; the branch is kept'
complete -c gwr -l delete-ignored \
    -d 'also delete the gitignored files in it; nothing restores them'
complete -c gwr -l no-forge -d 'decide from git alone; never ask GitHub/GitLab'
complete -c gwr -l all -n 'not __fish_seen_argument -s f -l force -l all' -d 'do it to every finished worktree'
complete -c gwr -s y -l yes -n '__fish_seen_argument -l all' -d 'go through with it'
complete -c gwr -s n -l dry-run -n '__fish_seen_argument -l all' -d 'only say what it would do'
complete -c gwr -l branch -n '__fish_seen_argument -l all' -r -a '(_gw_complete_branches)' \
    -d 'consider only this branch'
complete -c gwr -l fetch -n '__fish_seen_argument -l all' -d 'refresh the head branch first'
complete -c gwr -l no-fetch -n '__fish_seen_argument -l all' -d 'stay offline'
complete -c gwr -n 'not __fish_seen_argument -l all' -a '(_gw_complete_worktrees)'
