# gb! [QUERY] — the query is matched against branch names.
complete -c gb! -f
complete -c gb! -s h -l help -d 'show usage'
complete -c gb! -a '(_gw_complete_branches)' -d branch
