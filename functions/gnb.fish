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
    git fetch --all
    or _git_alias_say warn 'could not fetch — branching from what is already here'

    set -l head (_git_alias_main_branch)

    # Full refs, never `origin/main`: git resolves a bare name as a tag first,
    # so a repository holding a tag of that name would branch from the tag.
    # origin before upstream, and the remote copy before the local one, which
    # is the order _git_alias_main_branch itself asks in.
    set -l base
    set -l pretty
    for remote in origin upstream
        if git show-ref --verify --quiet refs/remotes/$remote/$head
            set base refs/remotes/$remote/$head
            set pretty $remote/$head
            break
        end
    end
    if not set -q base[1]
        if git show-ref --verify --quiet refs/heads/$head
            set base refs/heads/$head
            set pretty $head
        else
            _git_alias_say err "cannot tell which branch is the default — record it with: git remote set-head origin --auto"
            return 1
        end
    end

    # --no-track: a branch off origin/main would otherwise take the default
    # branch as its upstream, and git pull would merge it back in.
    if not git checkout --no-track -b $branch $base
        return 1
    end

    _git_alias_say info "$branch from $pretty at" (git rev-parse --short $base)
end
