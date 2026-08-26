function gw -d 'git worktree helpers: gwl, gwa, gwr'
    # Prints to stdout so it can be piped; the -h flag on the individual
    # commands prints the same text to stderr.

    # Through _gw_dest, so the line shows where gwa would actually land rather
    # than a second derivation of the same path that can drift from it.
    set -l here
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l p (_gw_dest NAME)
        test -n "$p"; and set here (string replace -r "^$HOME" '~' -- "$p")
    end

    echo 'gw — git worktree helpers'
    echo
    echo '  gwl [QUERY]              pick one of this repository'\''s worktrees and cd into it'
    echo '      -l, --list           print them instead, one per line: mark, branch, path'
    echo '  gwa [NAME] [BASE]        add a worktree for branch NAME (based on BASE), and cd into it'
    echo '      (no NAME)            pick a branch, or type a new name, with fzf'
    echo '      --fetch              also ask the remote whether NAME exists there already'
    echo '      --no-fetch           stay offline'
    echo '  gwr [PATH|QUERY]         remove a worktree whose branch is finished, and the branch'
    echo '      -f, --force          remove it even when it is not; the branch is kept'
    echo '      --no-forge           decide from git alone; never ask GitHub/GitLab'
    echo '      --all                do it to every finished worktree; a dry run without --yes'
    echo '        -y, --yes          go through with it'
    echo '        -n, --dry-run      say what would go and stop; wins over --yes'
    echo '        --branch NAME      consider only this branch'
    echo '        --fetch            refresh the head branch first (the default)'
    echo '        --no-fetch         decide offline: no fetch, and no forge either'
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
    echo '  set -g git_worktree_fetch no|yes|always     network policy for gwa (default: yes)'
    echo '  set -g git_worktree_remote NAME             force a remote (default: resolved per repo)'
    echo '  set -g git_worktree_forge no                never ask GitHub/GitLab'
end
