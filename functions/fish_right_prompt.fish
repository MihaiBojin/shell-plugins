function fish_right_prompt --description 'Battery status on the right, off unless asked for'
    # Off by default, like the Zsh battery-prompt. Autoloading this defines the
    # function but runs nothing; the checks below are two builtins and return
    # before any battery is read unless you opt in:
    #
    #   set -g shell_battery_prompt_show yes   # or -U to persist across sessions
    #
    # See functions/_shell_battery_prompt.fish for the segment itself, and put
    # it in a right prompt of your own if you want it shaped differently.
    # Set while the line that was just accepted is being repainted, so the
    # segment leaves the scrollback and only the live prompt carries it. See
    # conf.d/battery-prompt.fish.
    set -q _shell_rprompt_transient; and return 0
    set -q shell_battery_prompt_show; or return 0
    contains -- "$shell_battery_prompt_show" 1 yes true on; or return 0
    _shell_battery_prompt
end
