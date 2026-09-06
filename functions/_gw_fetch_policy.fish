function _gw_fetch_policy -a fallback -d 'The configured network policy, before any flag'
    # git-worktree-plugin.fetch is the shared key: the Zsh plugin and the
    # companion `origin` CLI read the same one, so a repository answers this
    # question once for all three. $git_worktree_fetch stays and still wins,
    # because it is how a person sets a preference for every repository at
    # once, which git config can only do through --global.
    if set -q git_worktree_fetch
        echo $git_worktree_fetch
        return 0
    end

    # Through a variable, and quoted: `test -n (cmd)` with no output leaves
    # test a lone -n, which is true.
    set -l answer (git config --get git-worktree-plugin.fetch 2>/dev/null)
    if test -n "$answer"
        echo $answer
        return 0
    end

    test -n "$fallback"; and echo $fallback; or echo always
end
