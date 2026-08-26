function _git_alias_branch_pick -a prompt query multi -d 'Pick local branches, printing one name per line'
    # fzf when it is there, a numbered list when it is not. Fuzzy search covers
    # the name column only: matching against the subject line makes every
    # branch match nearly every query.
    if not git rev-parse --git-dir >/dev/null 2>&1
        _git_alias_say err 'not inside a git repository'
        return 1
    end

    # Newest first. The branch you want is nearly always one you touched
    # recently, and %(HEAD) is the '*' that `git branch` prints.
    set -l records (git for-each-ref --sort=-committerdate refs/heads \
        --format='%(HEAD)%09%(refname:short)%09%(committerdate:relative)%09%(contents:subject)')
    if not set -q records[1]
        _git_alias_say err 'no local branches'
        return 1
    end

    set -l branches
    set -l lines
    for record in $records
        set -l fields (string split \t -- $record)
        set -a branches $fields[2]
        # Last field is the branch name, hidden from the display by
        # --with-nth and read by the preview as {-1}. The shown name is
        # truncated to 34 columns, which is not a ref.
        # %(HEAD) is '*' on the checked-out branch and a single space on every
        # other one, so this compares against the '*' rather than asking whether
        # the field is empty — a space is not.
        set -a lines (printf '%s %-34s\t%-14s\t%s\t%s' \
            (test "$fields[1]" = '*'; and echo '*'; or echo ' ') \
            (string sub -l 34 -- $fields[2]) $fields[3] $fields[4] $fields[2])
    end

    if command -q fzf
        # --select-1 only with a query. Without one the list is the point.
        set -l opts --ansi --height=50% --layout=reverse --border --tabstop=1 \
            --prompt="$prompt " --delimiter=\t --with-nth=1,2,3 --nth=1 \
            --color='hl:#ffcc00,info:#00ffcc,prompt:#ff00ff,pointer:#ff3300' \
            --preview='git -c color.ui=always log --oneline --decorate --graph -15 {-1}' \
            --preview-window='down:12:wrap'
        test -n "$multi"; and set -a opts --multi --bind='ctrl-a:toggle-all'
        if test -n "$query"
            set -a opts --query="$query" --select-1 --exit-0
        end
        set -l chosen (printf '%s\n' $lines | fzf $opts)
        or return 1
        set -q chosen[1]; or return 1
        for line in $chosen
            set -l index (contains --index -- $line $lines); or return 1
            echo $branches[$index]
        end
        return 0
    end

    # No fzf: a numbered list, filtered by the query if there was one.
    set -l shown
    for i in (seq (count $lines))
        test -z "$query"; or string match --quiet -- "*$query*" $branches[$i]; or continue
        set -a shown $i
    end
    if not set -q shown[1]
        _git_alias_say err "nothing matches: $query"
        return 1
    end
    if test (count $shown) -eq 1
        echo $branches[$shown[1]]
        return 0
    end
    for n in (seq (count $shown))
        printf '%3d) %s\n' $n $lines[$shown[$n]] >&2
    end
    # A failed read is not an empty answer. Without this, closed stdin falls
    # through to the [1] default and hands back a branch nobody chose — and the
    # caller deletes it.
    if not read --local --prompt-str="Choice [1]: " answer
        echo >&2
        return 1
    end
    test -n "$answer"; or set answer 1
    string match --quiet --regex '^[0-9]+$' -- $answer; or return 1
    test "$answer" -ge 1 -a "$answer" -le (count $shown); or return 1
    echo $branches[$shown[$answer]]
end
