function _shell_battery_prompt --description 'Print the battery segment, or nothing when the charge is fine'
    # The one thing in this package that runs a command between prompts:
    # `pmset` on macOS, sysfs reads on Linux. fish_right_prompt keeps it behind
    # $shell_battery_prompt_show; called on its own it always renders, so you
    # can drop it into a prompt of your own. Mirrors the Zsh _battery_prompt.

    # The cache counts prompts, not seconds. Fish has no fork-free clock -- no
    # $EPOCHSECONDS, no printf %()T -- so asking the time costs a `date` fork on
    # the very path that exists to avoid forks, about 2.5ms of every prompt. A
    # countdown costs nothing and answers the question that matters: how many
    # prompts ago did we last read the battery.
    #
    #   set -g shell_battery_prompt_cache_prompts 25   # default
    #   set -g shell_battery_prompt_cache_prompts 0    # read on every prompt
    #
    # The Zsh segment caches in seconds instead, because zsh/datetime gives it a
    # clock for free.
    set -l cache_prompts 25
    set -q shell_battery_prompt_cache_prompts
    and set cache_prompts $shell_battery_prompt_cache_prompts

    # Fast path: the countdown has not run out, so reuse the last rendering.
    # Most prompts end here, forking nothing.
    set -q _shell_battery_prompt_countdown
    or set -g _shell_battery_prompt_countdown 0
    if test "$cache_prompts" -gt 0 2>/dev/null
        and test $_shell_battery_prompt_countdown -gt 0
        set -g _shell_battery_prompt_countdown (math $_shell_battery_prompt_countdown - 1)
        test -n "$_shell_battery_prompt_cache_output"
        and printf '%s' "$_shell_battery_prompt_cache_output"
        return 0
    end

    set -l bat_pct
    set -l bat_time
    set -l charging

    # Keyed off pmset's presence, not $OSTYPE (which Fish does not set): macOS
    # always ships it, no Linux does, and a test can drop a stub on $PATH.
    if command -q pmset
        set -l out (command pmset -g batt 2>/dev/null | string collect)
        set bat_pct (string match -rg '([0-9]+)%' -- $out)[1]
        set bat_time (string match -rg '([0-9]+:[0-9]+) remaining' -- $out)[1]
        string match -q '*; charging;*' -- $out; and set charging 1
    else if test -r /sys/class/power_supply/BAT0/capacity
        # `read` is a builtin, so sysfs costs no process per prompt. Not
        # `status`: Fish reserves it for $?, and `read status` would abort.
        read -l bat_pct </sys/class/power_supply/BAT0/capacity
        set -l bat_status
        read -l bat_status </sys/class/power_supply/BAT0/status
        test "$bat_status" = Charging; and set charging 1
        if test -r /sys/class/power_supply/BAT0/energy_now
            and test -r /sys/class/power_supply/BAT0/power_now
            set -l energy_now
            set -l power_now
            read -l energy_now </sys/class/power_supply/BAT0/energy_now
            read -l power_now </sys/class/power_supply/BAT0/power_now
            if string match -qr '^[0-9]+$' -- $power_now; and test "$power_now" -gt 0
                set -l hours (math "floor($energy_now / $power_now)")
                set -l mins (math "floor(($energy_now % $power_now) * 60 / $power_now)")
                set bat_time (printf '%d:%02d' $hours $mins)
            end
        end
    end

    # Restart the countdown even with no battery, so a desktop asks once every
    # $cache_prompts prompts rather than on every one.
    set -g _shell_battery_prompt_countdown $cache_prompts

    if test -z "$bat_pct"
        set -g _shell_battery_prompt_cache_output ''
        return 0
    end

    set -l threshold_low 25
    set -q shell_battery_prompt_threshold_low
    and set threshold_low $shell_battery_prompt_threshold_low
    set -l threshold_high 50
    set -q shell_battery_prompt_threshold_high
    and set threshold_high $shell_battery_prompt_threshold_high

    set -l color_low ff5555
    set -q shell_battery_prompt_color_low; and set color_low $shell_battery_prompt_color_low
    set -l color_high f1fa8c
    set -q shell_battery_prompt_color_high; and set color_high $shell_battery_prompt_color_high
    set -l color_charging 50fa7b
    set -q shell_battery_prompt_color_charging
    and set color_charging $shell_battery_prompt_color_charging

    set -l icon
    set -l color
    if test -n "$charging"
        # Charging is always worth showing: it says the cable is doing its job.
        set icon '󰂄'
        set -q shell_battery_prompt_icon_charging; and set icon $shell_battery_prompt_icon_charging
        set color $color_charging
    else
        set icon '󰁻'
        set -q shell_battery_prompt_icon; and set icon $shell_battery_prompt_icon
        if test "$bat_pct" -le "$threshold_low"
            set color $color_low
        else if test "$bat_pct" -le "$threshold_high"
            set color $color_high
        else
            # Plenty of charge — say nothing at all.
            set -g _shell_battery_prompt_cache_output ''
            return 0
        end
    end

    set -l output "$icon $bat_pct%"

    # show_remaining defaults on; the wording matches the Zsh segment.
    set -l show_remaining 1
    set -q shell_battery_prompt_show_remaining
    and set show_remaining $shell_battery_prompt_show_remaining
    if contains -- "$show_remaining" 1 yes true on; and test -n "$bat_time"
        set output "$output ($bat_time"'h left)'
    end

    # Strip a leading '#', so '#ff5555' and 'ff5555' both feed set_color.
    set color (string replace -r '^#' '' -- $color)

    set -g _shell_battery_prompt_cache_output (set_color $color)"$output"(set_color normal)
    printf '%s' "$_shell_battery_prompt_cache_output"
end
