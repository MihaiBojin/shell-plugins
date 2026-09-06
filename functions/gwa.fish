function gwa -d 'Add a worktree for a branch beside the repository, and cd into it'
    argparse --name=gw h/help fetch no-fetch -- $argv
    or return 2
    if set -q _flag_help
        gw >&2
        return 0
    end

    set -l name $argv[1]
    set -l base $argv[2]
    if test (count $argv) -gt 2
        _gw_say err 'too many arguments — usage: gwa NAME [BASE]'
        return 2
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        _gw_say err 'not inside a git repository'
        return 1
    end

    # No NAME: pick one. This is the set gwl cannot show — a branch that exists
    # on the remote but has no worktree yet is invisible to a picker over
    # worktrees.
    if test -z "$name"
        _gw_pick_branch 'branch>'; or return $status
        set name $_gw_reply
        test -n "$name"; or return 1
    end
    if not git check-ref-format refs/heads/$name 2>/dev/null
        _gw_say err "invalid branch name: $name"
        return 2
    end

    set -l dest (_gw_dest $name | string collect)
    if test -z "$dest"
        _gw_say err 'cannot locate this repository main worktree'
        return 1
    end
    set -l wtdir (_gw_wt_dir | string collect)
    set -l remote (_gw_remote)

    # Is this directory already spoken for, and by whom? Three positions of the
    # same question, none of which `git worktree list` can answer: a squatter
    # belongs to another repository, so this one has never heard of it and the
    # list comes back empty — which reads exactly like "nothing is there".
    if test -e "$dest/.git"
        if not _gw_owns $dest
            _gw_say err "$dest is a worktree of $_gw_reply, not of this repository"
            _gw_say err 'move it, or pick a name that does not collide with it'
            return 1
        end

        # Ours. Normally the same branch asked for twice; say whose it is when it
        # is not, rather than cd-ing somebody into a worktree they did not ask
        # for.
        set -l occupant ''
        for record in (_gw_records | string split0)
            set -l fields (string split (printf '\x1f') -- $record)
            test (path resolve $fields[1] | string collect) = (path resolve $dest | string collect); or continue
            set occupant $fields[3]
            break
        end
        if test -z "$occupant" -o "$occupant" = "$name"
            _gw_say info "worktree already exists: $dest"
            cd $dest
            return 0
        end
        _gw_say err "$dest is the worktree for '$occupant', not '$name'"
        return 1
    end

    # Branch names nest, so one branch's worktree can be another's parent
    # directory: branch `fix` in a repository called `login` occupies
    # <root>/fix/login, which is exactly where branch `fix/login` puts its
    # repositories. Neither can have it, and git's own message for either
    # collision says only "already exists".
    set -l ancestor (path dirname $dest | string collect)
    while test -n "$wtdir"; and string match --quiet -- "$wtdir/*" $ancestor
        if test -e "$ancestor/.git"
            if _gw_owns $ancestor
                set -l owner ''
                for record in (_gw_records | string split0)
                    set -l fields (string split (printf '\x1f') -- $record)
                    test (path resolve $fields[1] | string collect) = (path resolve $ancestor | string collect); or continue
                    set owner $fields[3]
                    break
                end
                if test -n "$owner"
                    _gw_say err "$ancestor is this repository's worktree for '$owner' — '$name' would nest inside it"
                else
                    _gw_say err "$ancestor is this repository's worktree — '$name' would nest inside it"
                end
            else
                _gw_say err "$ancestor is a worktree of $_gw_reply — '$name' would nest inside it"
            end
            _gw_say err 'pick a branch name that is not a prefix of it, or move that worktree'
            return 1
        end
        set ancestor (path dirname $ancestor | string collect)
    end

    if test -d "$dest"
        # Hidden entries count too: `.git` is what a nested worktree leaves.
        set -l squatters $dest/* $dest/.*
        if set -q squatters[1]
            _gw_say err "$dest already exists and is not empty — another branch is nesting under it"
            return 1
        end
    end

    # Already checked out somewhere? Go there rather than failing.
    for record in (_gw_records | string split0)
        set -l fields (string split (printf '\x1f') -- $record)
        test "$fields[3]" = "$name"; or continue
        _gw_say info "branch '$name' is already checked out at $fields[1]"
        cd $fields[1]
        return 0
    end

    # none: stay offline. base: refresh the branch we are about to fork from.
    # full: also ask the remote whether NAME itself already exists.
    set -l mode base
    set -q git_worktree_fetch; and set mode $git_worktree_fetch
    set -q _flag_fetch; and set mode always
    set -q _flag_no_fetch; and set mode no
    switch $mode
        case no false off 0
            set mode none
        case always all
            set mode full
        case '*'
            set mode base
    end
    set -l online 1
    test "$mode" = none; and set online 0

    # Resolve what to branch off: a remote-tracking ref when there is one, so new
    # branches start from what the remote has rather than a stale local copy.
    set -l start
    if test -n "$base"
        if test -n "$remote"; and git show-ref --verify --quiet refs/remotes/$remote/$base
            set start refs/remotes/$remote/$base
        else if git rev-parse --verify --quiet $base^{commit} >/dev/null
            # An explicit BASE is whatever the person named — a tag here is
            # deliberate.
            set start $base
        else if test "$online" = 1; and test -n "$remote"
            _gw_say info "fetching $remote/$base"
            if git fetch --quiet $remote $base
                set start refs/remotes/$remote/$base
                git show-ref --verify --quiet refs/remotes/$remote/$base; or set start FETCH_HEAD
            else
                _gw_say err "unknown base: $base"
                return 1
            end
        else
            _gw_say err "unknown base: $base"
            return 1
        end
    else
        set start (_gw_head_branch "$remote" $online)
        if test -z "$start"
            _gw_say err 'cannot determine the default branch — pass BASE explicitly, or record it with'
            _gw_say err "  git remote set-head $remote --auto"
            return 1
        end
    end

    # refs/remotes/origin/main is what git is handed; origin/main is what is said.
    set -l start_disp (string replace -r '^refs/(remotes|heads)/' '' -- $start)

    if test "$online" = 1; and test -n "$remote"; and string match --quiet -- "refs/remotes/$remote/*" $start
        _gw_say info "fetching $start_disp"
        git fetch --quiet $remote (string replace -- "refs/remotes/$remote/" '' $start)
        or _gw_say warn "using the local copy of $start_disp"
    end

    # --fetch: NAME may exist on the remote without us knowing yet. Checking
    # costs a round trip, so it is opt-in; skipping it would fork a second,
    # divergent branch of the same name off the base.
    if test "$mode" = full; and test -n "$remote"
        and not git show-ref --verify --quiet refs/heads/$name
        and not git show-ref --verify --quiet refs/remotes/$remote/$name
        _gw_say info "asking $remote about '$name'"
        set -l found (git ls-remote --heads $remote $name 2>/dev/null)
        if set -q found[1]
            _gw_say info "$remote already has '$name' — tracking it instead of branching"
            git fetch --quiet $remote $name; or _gw_say warn "could not fetch $remote/$name"
        end
    end

    # A .worktrees/ beside the repo is untracked junk if the parent is itself
    # inside a working tree, and `git clean -xdff` there would delete it.
    if not test -d "$wtdir"; and git -C (path dirname $wtdir | string collect) rev-parse --is-inside-work-tree >/dev/null 2>&1
        _gw_say warn (path dirname $wtdir | string collect)" is inside a git working tree — add "(path basename $wtdir | string collect)"/ to its .gitignore"
    end

    mkdir -p (path dirname $dest | string collect); or return 1

    set -l label
    set -l add
    if git show-ref --verify --quiet refs/heads/$name
        set label "checking out '$name'"
        set add git worktree add $dest $name
    else if test -n "$remote"; and git show-ref --verify --quiet refs/remotes/$remote/$name
        set label "checking out '$name' tracking $remote/$name"
        set add git worktree add --track -b $name $dest $remote/$name
    else
        set label "creating '$name' from $start_disp"
        set add git worktree add --no-track -b $name $dest $start
    end

    _gw_say info $label
    if not $add
        _gw_prune_upto $dest (_gw_main_worktree | string collect)
        return 1
    end
    _gw_say info $dest
    cd $dest
end
