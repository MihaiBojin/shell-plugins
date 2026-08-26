function gwl -d 'Pick one of this repository worktrees and cd into it, or --list them'
    argparse h/help l/list -- $argv
    or return 2
    if set -q _flag_help
        gw >&2
        return 0
    end
    if test (count $argv) -gt 1
        _gw_say err 'too many arguments — usage: gwl [QUERY]'
        return 2
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        _gw_say err 'not inside a git repository'
        return 1
    end

    # --list prints them instead, which is the only way to see the set without
    # moving into one of them, and the only form that can be piped.
    if set -q _flag_list
        if test (count $argv) -gt 0
            _gw_say err 'gwl --list takes no QUERY'
            return 2
        end
        _gw_plain_list
        return $status
    end

    set -l dest (_gw_pick 'worktree>' "$argv[1]"); or return 1
    if not test -d "$dest"
        _gw_say err "no such directory: $dest"
        return 1
    end
    cd $dest
end
