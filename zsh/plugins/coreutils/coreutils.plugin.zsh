#
# coreutils — colour for ls, grep and diff, and the two long listings.
#
#   ll     ls -lh
#   lla    ls -alh
#
# --color=auto colours a terminal and nothing else, so a pipe or a redirect
# gets the bytes it always did. GNU and current BSD ls and grep take it; an
# older BSD diff does not, so diff asks on first use (functions/diff).
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz diff

alias ls='ls --color=auto'
alias gls='gls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lh'
alias lla='ls -alh'
