function gwm -d "Rename this worktree's branch and move its checkout to match"
    # Directory name equals branch name is the invariant every tool writing into
    # this root keeps, so renaming a branch is two operations that have to
    # happen together: `git branch -m` and `git worktree move`. Doing one
    # without the other leaves a worktree whose directory says one thing and
    # whose HEAD says another, which is the state gwl and gwr both read wrong.
    #
    # Three pieces of tidying git does not do on its own: the new parent has to
    # exist before `git worktree move` will write into it, the old one is left
    # behind empty, and neither is `git worktree move`'s business.
    argparse --name=gw h/help -- $argv
    or return 2
    if set -q _flag_help
        gw >&2
        return 0
    end

    set -l new $argv[1]
    if test -z "$new"
        _gw_say err 'NEW is required — usage: gwm NEW'
        return 2
    end
    if test (count $argv) -gt 1
        _gw_say err 'too many arguments — usage: gwm NEW'
        return 2
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        _gw_say err 'not inside a git repository'
        return 1
    end
    if not git check-ref-format refs/heads/$new 2>/dev/null
        _gw_say err "invalid branch name: $new"
        return 2
    end

    set -l main (_gw_main_worktree | string collect)
    if test -z "$main"
        _gw_say err 'cannot locate this repository main worktree'
        return 1
    end

    set -l us (printf '\x1f')
    set -l records (_gw_records | string split0)
    set -l cwd (path resolve $PWD | string collect)
    set -l mainr (path resolve $main | string collect)

    # The worktree you are standing in — found by asking which record contains
    # $PWD, rather than assuming $PWD is its root — or one you pick. The main
    # checkout is neither: git cannot move it, and its directory name is not a
    # branch name.
    set -l src ''
    for record in $records
        set -l fields (string split $us -- $record)
        set -l here (path resolve $fields[1] | string collect)
        test "$here" = "$mainr"; and continue
        if test "$cwd" = "$here"; or string match --quiet -- "$here/*" $cwd
            set src $fields[1]
            break
        end
    end
    if test -z "$src"
        if test "$cwd" != "$mainr"; and not string match --quiet -- "$mainr/*" $cwd
            _gw_say err "not inside one of this repository's worktrees"
            return 1
        end
        _gw_pick 'move>' ''; or return 1
        set src $_gw_reply
    end
    if test (path resolve $src | string collect) = "$mainr"
        _gw_say err "refusing to move the main worktree: $src"
        return 1
    end

    # What is checked out there, and is it something that can be renamed?
    set -l branch ''
    set -l flags ''
    for record in $records
        set -l fields (string split $us -- $record)
        test (path resolve $fields[1] | string collect) = (path resolve $src | string collect); or continue
        set branch $fields[3]
        set flags $fields[4]
        break
    end

    if string match --quiet '*locked*' -- $flags
        _gw_say err "$src is locked — unlock it first:"
        echo "  git -C $main worktree unlock $src" >&2
        return 1
    end
    if test -z "$branch"
        _gw_say err "$src has no branch checked out — there is nothing to rename"
        return 1
    end
    if test "$branch" = "$new"
        _gw_say err "$branch is already called that"
        return 1
    end
    if git show-ref --verify --quiet refs/heads/$new
        _gw_say err "branch '$new' already exists"
        return 1
    end

    set -l dest (_gw_dest $new | string collect)
    if test -z "$dest"
        _gw_say err "cannot work out where $new would go"
        return 1
    end

    # The same collisions gwa refuses, for the same reasons: the destination can
    # already exist, or one of our own worktrees can be nesting above it.
    if test -e "$dest"
        _gw_say err "$dest already exists"
        return 1
    end
    set -l up (path dirname $dest | string collect)
    while not test -e "$up"; and string match --quiet '*/*' -- $up
        set up (path dirname $up | string collect)
    end
    if test -e "$up/.git"; and not _gw_owns $up
        _gw_say err "$up is a worktree of $_gw_reply — '$new' would nest inside it"
        _gw_say err 'pick a name that is not a prefix of it, or move that worktree'
        return 1
    end

    echo "Rename $branch to $new" >&2
    echo "  $src" >&2
    echo "  $dest" >&2
    read --local --prompt-str='Proceed? [y/N] ' answer
    or begin
        echo >&2
        return 1
    end
    if not string match --quiet --regex '^[Yy]' -- "$answer"
        _gw_say info 'left alone'
        return 1
    end

    # The branch first: `git worktree move` records the new path, and renaming
    # afterwards would leave the two steps recoverable in the wrong order if the
    # move failed.
    _gw_say info "renaming $branch"
    if not git -C $main branch -m $branch $new
        return 1
    end

    if not mkdir -p (path dirname $dest | string collect)
        _gw_say err "could not create "(path dirname $dest | string collect)
        _gw_say warn "the branch is now $new; its worktree is still at $src"
        return 1
    end

    _gw_say info "moving "(path basename $src | string collect)
    if not git -C $main worktree move $src $dest
        _gw_say err "the branch is now $new; its worktree is still at $src"
        echo "  finish it with: git -C $main worktree move $src $dest" >&2
        return 1
    end

    _gw_prune_upto $src $main

    # Follow it, if that is where we were standing.
    if test "$cwd" = (path resolve $src | string collect); or string match --quiet -- (path resolve $src | string collect)"/*" $cwd
        cd $dest
    end
    _gw_say info "$new is at $dest"
end
