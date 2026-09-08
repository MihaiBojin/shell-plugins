function gnb -d 'Branch from the default branch, brought up to date first'
    argparse h/help -- $argv
    or return 2

    if set -q _flag_help
        echo 'gnb NAME          fetch, then branch NAME off the default branch and check it out' >&2
        echo '' >&2
        echo 'The base is <remote>/<default branch> as it stands after the fetch, so' >&2
        echo 'the branch starts from what the server has rather than from the local' >&2
        echo 'copy. Nothing is rebased afterwards: a branch created there is already' >&2
        echo 'on top of it.' >&2
        return 0
    end

    if test (count $argv) -ne 1
        _git_alias_say err 'usage: gnb NAME'
        return 2
    end
    set -l branch $argv[1]

    if not git rev-parse --git-dir >/dev/null 2>&1
        _git_alias_say err 'not inside a git repository'
        return 1
    end

    if not git check-ref-format --branch $branch >/dev/null 2>&1
        _git_alias_say err "$branch is not a valid branch name"
        return 2
    end

    if git show-ref --verify --quiet refs/heads/$branch
        _git_alias_say err "$branch is already a branch — gb $branch checks it out"
        return 1
    end

    # A failed fetch is not fatal. An offline machine still gets a branch, off
    # whatever it last saw, and the line at the end names the commit it got.
    # --all rather than the one remote the base comes from: a remote that fails
    # is a repository to fix, not a reason to fetch less.
    git fetch --all
    or _git_alias_say warn 'some remotes could not be fetched — branching from what is already here'

    # Which remote, then that remote's own default branch. Neither is assumed:
    # a repository with several remotes answers through git's own configuration,
    # and each remote advertises a default of its own.
    set -l remote (_git_alias_remote)
    set -l head (_git_alias_main_branch $remote)

    # Full refs, never `origin/main`: git resolves a bare name as a tag first,
    # so a repository holding a tag of that name would branch from the tag.
    set -l base
    set -l pretty
    if test -n "$remote"; and git show-ref --verify --quiet refs/remotes/$remote/$head
        set base refs/remotes/$remote/$head
        set pretty $remote/$head
    else if git show-ref --verify --quiet refs/heads/$head
        set base refs/heads/$head
        set pretty $head
    else
        _git_alias_say err "cannot tell which branch is the default — record it with: git remote set-head "(test -n "$remote"; and echo $remote; or echo origin)" --auto"
        return 1
    end

    # --no-track: a branch off origin/main would otherwise take the default
    # branch as its upstream, and git pull would merge it back in.
    if not git checkout --no-track -b $branch $base
        return 1
    end

    _git_alias_say info "$branch from $pretty at" (git rev-parse --short $base)
end
