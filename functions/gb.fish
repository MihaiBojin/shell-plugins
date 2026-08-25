function gb -d 'Pick a branch and check it out'
    argparse h/help l/list -- $argv
    or return 2

    if set -q _flag_help
        echo 'gb [QUERY]        pick one of this repository'\''s branches and check it out' >&2
        echo 'gb --list [ARG…]  what `git branch` prints, arguments passed straight through' >&2
        echo '' >&2
        echo 'Fuzzy search covers the branch name. The preview shows its recent' >&2
        echo 'commits. A QUERY that narrows to one branch checks it out without asking.' >&2
        return 0
    end

    if set -q _flag_list
        git branch $argv
        return
    end

    if test (count $argv) -gt 1
        _git_alias_say err 'too many arguments — usage: gb [QUERY]'
        return 2
    end

    set -l chosen (_git_alias_branch_pick 'branch>' "$argv[1]"); or return 1
    git checkout $chosen[1]
end
