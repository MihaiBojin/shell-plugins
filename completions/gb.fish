# gb [QUERY] — the query is matched against branch names.
complete -c gb -f
complete -c gb -s h -l help -d 'show usage'
complete -c gb -s l -l list -d 'what `git branch` prints, arguments passed straight through'
complete -c gb -n 'not __fish_seen_argument -s l -l list' -a '(_gw_complete_branches)' -d branch
