function grep --wraps grep -d 'grep, coloured on a terminal'
    command grep --color=auto $argv
end
