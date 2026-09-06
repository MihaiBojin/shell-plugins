function _gw_confirm -a question -d 'Ask QUESTION and succeed only on yes'
    # `read` fails at EOF, and that is the answer when there is no terminal to
    # ask on: no is the safe half of every question this gets asked. The Zsh
    # half does the same, so a script reaching either one is refused rather
    # than answered for.
    read --local --prompt-str="$question [y/N] " answer
    or begin
        echo >&2
        return 1
    end
    string match --quiet --regex '^[Yy]' -- "$answer"
end
