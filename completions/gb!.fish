# gb! [QUERY] — the query is matched against branch names.
complete -c gb! -f
complete -c gb! -s h -l help -d 'show usage'
complete -c gb! -a '(git for-each-ref --format="%(refname:short)" \
    refs/heads refs/remotes 2>/dev/null)' -d branch
