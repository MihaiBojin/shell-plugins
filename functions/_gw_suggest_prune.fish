function _gw_suggest_prune -a main -d 'Say so when stale worktree metadata is left behind'
    set -l stale (git -C $main worktree prune --dry-run --verbose 2>/dev/null)
    set -q stale[1]; or return 0
    _gw_say warn "stale worktree metadata remains; clear it with: git -C $main worktree prune"
end
