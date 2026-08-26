function _gw_pick -a prompt query -d 'Pick one of the worktrees here, printing its path'
    # fzf when it is there, a numbered list when it is not. Fuzzy search covers
    # the branch column only: the path is shown but not searched, since
    # fuzzy-matching a long absolute path makes every entry match everything.
    set -l records (_gw_records | string split0); or return 1
    set -l us (printf '\x1f')

    set -l lines
    set -l paths
    set -l cwd (path resolve $PWD)
    for record in $records
        set -l fields (string split $us -- $record)
        set -l wt $fields[1]
        set -l branch $fields[3]
        set -l flags $fields[4]
        if test -z "$branch"
            if string match --quiet '*bare*' -- $flags
                set branch '(bare)'
            else if string match --quiet '*detached*' -- $flags
                set branch '(detached)'
            else
                set branch '?'
            end
        end
        set -l here (path resolve $wt)
        set -l mark ' '
        if test "$cwd" = "$here"; or string match --quiet -- "$here/*" $cwd
            set mark '*'
        end
        set -a paths $wt
        # Last field is the real path, hidden from the display by --with-nth
        # and read by the preview as {-1}. The shown path is shortened to ~,
        # which git cannot chdir to — nothing expands a tilde inside an
        # argument fzf hands to a shell.
        set -a lines (printf '%s %-30s\t%s\t%s' $mark (string sub -l 30 -- $branch) (string replace -r "^$HOME" '~' -- $wt) $wt)
    end

    if command -q fzf
        # --select-1 only with a query. Without one the list is the point: a
        # repository with a single worktree would otherwise pick it and exit
        # having drawn nothing, which reads as `gwl` doing nothing at all.
        set -l opts --ansi --height=50% --layout=reverse --border --tabstop=1 \
            --prompt="$prompt " --delimiter=\t --with-nth=1,2 --nth=1 \
            --color='hl:#ffcc00,info:#00ffcc,prompt:#ff00ff,pointer:#ff3300' \
            --preview='git -C {-1} -c color.ui=always status --short --branch; echo; git -C {-1} -c color.ui=always log --oneline --decorate -15' \
            --preview-window='down:12:wrap'
        if test -n "$query"
            set -a opts --query="$query" --select-1 --exit-0
        end
        set -l chosen (printf '%s\n' $lines | fzf $opts)
        or return 1
        set -q chosen[1]; or return 1
        set -l index (contains --index -- $chosen $lines); or return 1
        echo $paths[$index]
        return 0
    end

    # No fzf: a numbered list, filtered by the query if there was one.
    set -l shown
    for i in (seq (count $lines))
        test -z "$query"; or string match --quiet -- "*$query*" $lines[$i]; or continue
        set -a shown $i
    end
    set -q shown[1]; or begin
        _gw_say err "nothing matches: $query"
        return 1
    end
    if test (count $shown) -eq 1
        echo $paths[$shown[1]]
        return 0
    end
    for n in (seq (count $shown))
        printf '%3d) %s\n' $n $lines[$shown[$n]] >&2
    end
    # A failed read is not an empty answer: closed stdin would otherwise fall
    # through to the [1] default and pick a worktree nobody chose.
    if not read --local --prompt-str="Choice [1]: " answer
        echo >&2
        return 1
    end
    test -n "$answer"; or set answer 1
    string match --quiet --regex '^[0-9]+$' -- $answer; or return 1
    test "$answer" -ge 1 -a "$answer" -le (count $shown); or return 1
    echo $paths[$shown[$answer]]
end
