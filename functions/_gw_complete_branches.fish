function _gw_complete_branches -d 'Branch names for completion: local, then remote-tracking'
    # Deliberately not through _gw_records: this is every branch, not the ones
    # that happen to have a worktree.
    git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null
end
