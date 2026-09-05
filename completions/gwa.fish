# gwa [NAME] [BASE] — NAME is usually a branch that does not exist yet, so
# nothing is offered for it; BASE is an existing ref. With no NAME at all the
# command opens its own picker.
complete -c gwa -f
complete -c gwa -s h -l help -d 'show usage'
complete -c gwa -l fetch -d 'check whether the remote already has NAME'
complete -c gwa -l no-fetch -d 'stay offline'
complete -c gwa -n _gw_complete_is_base -a '(_gw_complete_branches)' -d 'base branch'
