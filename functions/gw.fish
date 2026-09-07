function gw -d 'git worktree helpers: gwl, gwa, gwr'
    # Prints to stdout so it can be piped; the -h flag on the individual
    # commands prints the same text to stderr.

    # Through _gw_dest, so the line shows where gwa would actually land rather
    # than a second derivation of the same path that can drift from it.
    set -l here
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l p (_gw_dest NAME | string collect)
        test -n "$p"; and set here (string replace -r "^$HOME" '~' -- "$p")
    end

    echo 'gw — git worktree helpers'
    echo
    echo '  gwl [QUERY]              pick one of this repository'\''s worktrees and cd into it'
    echo '      -l, --list           print them instead, one per line: mark, branch, path'
    echo '  gwa [NAME] [BASE]        add a worktree for branch NAME (based on BASE), and cd into it'
    echo '      (no NAME)            pick a branch, or type a new name, with fzf'
    echo '      --fetch              ask the remote whether NAME exists there already (the default)'
    echo '      --no-fetch           stay offline'
    echo '  gwm NEW                  rename this worktree'\''s branch to NEW and move it to match'
    echo '  gwr [PATH|QUERY]         remove a worktree whose branch is finished, and the branch'
    echo '      -f, --force          remove it even when it is not; the branch is kept'
    echo '      --delete-ignored     also delete its gitignored files; nothing restores them'
    echo '      --no-forge           decide from git alone; never ask GitHub/GitLab'
    echo '      -y, --yes            do not ask before removing; ignored files still ask'
    echo '  gw,  gwh                 this help'
    echo
    echo 'worktrees live beside their repository, at'
    echo '  <PARENT>/.worktrees/<NAME>/<REPO>'
    if test -n "$here"
        echo "  here   $here"
    else
        echo '  here   (not inside a git repository)'
    end
    echo
    echo 'configure with global variables, e.g. in conf.d/:'
    echo '  set -g git_worktree_fetch no|yes|always     network policy for gwa (default: always)'
    echo '  git config git-worktree-plugin.fetch no    the same, per repository, shared with origin'
    echo '  set -g git_worktree_remote NAME             force a remote (default: resolved per repo)'
    echo '  set -g git_worktree_forge no                never ask GitHub/GitLab'
end
