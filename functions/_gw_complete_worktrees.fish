function _gw_complete_worktrees -d "This repository's worktrees, as path<TAB>branch, for completion"
    # `complete -a` reads a tab as the separator between the candidate and its
    # description, so the branch becomes the description of the path.
    #
    # Split on the tab rather than through `read`: the mark column is a space
    # for every worktree but the one you are in, and read's default separators
    # would swallow it and shift every field left.
    _gw_plain_list 2>/dev/null | while read -l line
        set -l f (string split \t -- $line)
        test (count $f) -eq 3; or continue
        printf '%s\t%s\n' $f[3] $f[2]
    end
end
