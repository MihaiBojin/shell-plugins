function _gw_pick_branch -a prompt -d 'Pick a branch to make a worktree for, leaving it in $_gw_reply'
    # Every local branch, plus the remote's branches that have no local
    # counterpart — the set gwl can never show, because gwl only knows about
    # worktrees that already exist and this is the list of ones that do not.
    #
    # Leaves the chosen branch in $_gw_reply. With fzf a name that matches nothing is the
    # answer too: typing one and pressing enter is how a new branch is named,
    # the same way `gwa NAME` names one.
    set -g _gw_reply ''
    set -l remote (_gw_remote)
    set -l us (printf '\x1f')

    set -l locals (git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads)
    if not set -q locals[1]
        _gw_say err 'no branches'
        return 1
    end

    # Which branches already have a worktree, so the list can say so rather
    # than leaving you to find out by being moved somewhere unexpected.
    set -l checked_out
    for record in (_gw_records | string split0)
        set -l fields (string split $us -- $record)
        test -n "$fields[3]"; and set -a checked_out $fields[3]
    end

    set -l names
    set -l lines
    for b in $locals
        set -a names $b
        set -l note local
        contains -- $b $checked_out; and set note 'has a worktree'
        set -a lines (printf '%-34s\t%-14s\t%s' (string sub -l 34 -- $b) $note $b)
    end
    if test -n "$remote"
        for r in (git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/$remote)
            # refs/remotes/<remote>/HEAD shortens to the remote's own name,
            # not to <remote>/HEAD, so it arrives looking like a branch called
            # `origin`.
            test "$r" = "$remote"; and continue
            set -l b (string replace -- "$remote/" '' $r)
            test "$b" = HEAD; and continue
            contains -- $b $names; and continue
            set -a names $b
            set -a lines (printf '%-34s\t%-14s\t%s' (string sub -l 34 -- $b) "on $remote" $b)
        end
    end

    if not command -q fzf
        # A numbered list of every branch in the repository is noise, and there
        # is no query here to narrow it with. Name the branch instead.
        _gw_say err 'NAME is required — usage: gwa NAME [BASE]'
        return 2
    end

    set -l out (printf '%s\n' $lines | fzf --ansi --height=50% --layout=reverse --border \
        --tabstop=1 --prompt="$prompt " --delimiter=\t --with-nth=1,2 --nth=1 \
        --print-query \
        --color='hl:#ffcc00,info:#00ffcc,prompt:#ff00ff,pointer:#ff3300' \
        --preview='git -c color.ui=always log --oneline --decorate --graph -15 {-1} 2>/dev/null' \
        --preview-window='down:12:wrap')

    set -q out[1]; or return 1

    # Which line is which cannot be counted on: fzf emits an empty first line
    # for an empty query, and zsh's (f) drops it where fish keeps it. So ask
    # whether the last line is one of the lines offered — if it is, it is the
    # selection, and if it is not, nothing matched and the query is a branch
    # name nobody has used yet.
    set -l index (contains --index -- $out[-1] $lines)
    if test -n "$index"
        set -g _gw_reply $names[$index]
        return 0
    end
    test -n "$out[1]"; or return 1
    set -g _gw_reply $out[1]
end
