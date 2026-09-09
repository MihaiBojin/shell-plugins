# gbd! [QUERY] — the query is matched against branch names. Only local ones can
# be deleted, so only those are offered.
complete -c gbd! -f
complete -c gbd! -s h -l help -d 'show usage'
complete -c gbd! -s f -l force -d 'delete without the confirmation prompt'
complete -c gbd! -a '(git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null)' -d branch
