# gwl [QUERY] — the query is free text the picker matches against branch names,
# so those are what is worth offering.
complete -c gwl -f
complete -c gwl -s h -l help -d 'show usage'
complete -c gwl -s l -l list -d 'print the worktrees instead of picking one'
complete -c gwl -n 'not __fish_seen_argument -s l -l list' -a '(_gw_complete_branches)' -d branch
