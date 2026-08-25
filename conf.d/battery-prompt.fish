# battery-prompt — the right prompt leaves the line once the line is accepted.
#
# The right prompt is drawn on the same row as the command, so copying that row
# out of the scrollback takes the battery reading with it. Zsh has
# TRANSIENT_RPROMPT for exactly this; Fish has no such option, so Enter is
# rebound to blank the segment and repaint before the line runs.
#
# Only for a shell that asked for the segment: nothing here rebinds Enter in a
# shell that has no right prompt to erase. To keep the segment on every line:
#
#   set -g shell_battery_prompt_transient no
#
# Both variables are read at the first prompt, so set them in config.fish.

status is-interactive; or exit

function _shell_rprompt_execute -d 'Blank the right prompt on this line, then run it'
    # An incomplete line — an open quote, a half-written `if` — is not going to
    # run, and repainting it without the segment would erase something still
    # live on screen.
    if commandline --is-valid
        set -g _shell_rprompt_transient 1
        commandline -f repaint
    end
    commandline -f execute
end

function _shell_rprompt_restore --on-event fish_prompt -d 'The next prompt gets its segment back'
    set -e _shell_rprompt_transient
end

function _shell_rprompt_bind --on-event fish_prompt -d 'Bind Enter once, after Fish has installed its own bindings'
    # conf.d runs before Fish sets its key bindings up, which would undo a bind
    # made here. The first prompt is the earliest moment the bindings exist.
    functions --erase _shell_rprompt_bind

    set -q shell_battery_prompt_show; or return 0
    contains -- "$shell_battery_prompt_show" 1 yes true on; or return 0
    if set -q shell_battery_prompt_transient
        contains -- "$shell_battery_prompt_transient" 0 no false off; and return 0
    end

    for mode in (bind --list-modes)
        bind -M $mode \r _shell_rprompt_execute
        bind -M $mode \n _shell_rprompt_execute
    end
end
