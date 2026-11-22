#
# kubectl — short names for kubectl.
#
#   k, kube    kubectl
#   kes POD    the events for one pod, oldest first
#
# Requires `kubectl` at call time, not at load time.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz kes

alias k='kubectl'
alias kube='kubectl'
