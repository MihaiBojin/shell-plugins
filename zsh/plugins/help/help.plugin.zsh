#
# help — list every shortcut this collection defines.
#
#   shell-plugins-help   one line a shortcut: the name, then what it does
#
# The list is functions/shell-plugins-help.tsv at the repository root, which
# the Fish function reads too.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz shell-plugins-help
