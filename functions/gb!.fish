function gb! -d 'Pick a branch and check it out'
    argparse h/help -- $argv
    or return 2

    if set -q _flag_help
        echo 'gb! [QUERY]       pick one of this repository'\''s branches and check it out' >&2
        echo '' >&2
        echo 'Fuzzy search covers the branch name. The preview shows its recent' >&2
        echo 'commits. A QUERY that narrows to one branch checks it out without asking.' >&2
        echo '`gb` is git branch itself, so gb -d, gb -a and the rest pass through.' >&2
        return 0
    end

    if test (count $argv) -gt 1
        _git_alias_say err 'too many arguments — usage: gb! [QUERY]'
        return 2
    end

    _git_alias_branch_pick 'branch>' "$argv[1]"; or return 1
    set -l chosen $_git_alias_reply
    git checkout $chosen[1]
end
