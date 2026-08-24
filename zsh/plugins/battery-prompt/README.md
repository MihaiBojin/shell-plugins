# battery-prompt

Appends battery status to `RPROMPT` when the charge drops below a threshold —
or whenever the machine is charging.

**Off by default.** It is the only thing in this repository that runs a command
between prompts (`pmset` on macOS, sysfs reads on Linux, roughly 10ms), so it
has to be asked for explicitly:

```zsh
zstyle ':battery-prompt:' show yes
```

The answer is cached (`cache_seconds`, default 60) so holding down Return does
not fork `pmset` once per prompt. Machines without a battery cache the empty
answer too, and cost one `pmset` a minute at most.

Fish has the same segment, as `fish_right_prompt` — see [Fish](#fish) below.

## Load order

It appends to whatever `RPROMPT` already holds, so it must load **after**
`prompt`, which clears it:

```text
MihaiBojin/shell-plugins path:zsh/plugins/prompt
MihaiBojin/shell-plugins path:zsh/plugins/battery-prompt
```

The aggregate entry point (`shell-plugins.plugin.zsh`) already orders them
this way.

Enabling `show` also turns on `PROMPT_SUBST`, because the segment is a command
substitution inside `RPROMPT`. Nothing else in this repository needs it.

## Configuration

All styles are read when the segment renders, except `show` and
`cache_seconds`, which are read when the plugin loads — so set those before it.

Setting any of them is what makes them readable at all: `zstyle` is a builtin
from `zsh/zutil`, and the plugin asks for `show` only when that module is
already loaded. Nothing is configured if nothing loaded it, and loading it to
be told so would cost 3.5 ms in a plugin that is off by default.

```zsh
# Display control
zstyle ':battery-prompt:' show yes             # enable the RPROMPT segment (default: no)
zstyle ':battery-prompt:' show_remaining no    # hide time remaining (default: yes)
zstyle ':battery-prompt:' cache_seconds 0      # cache for N seconds (default: 60, 0 disables)

# Thresholds — the segment appears only at or below threshold_high
zstyle ':battery-prompt:' threshold_low 25     # red at or below this (default: 25)
zstyle ':battery-prompt:' threshold_high 50    # yellow at or below this (default: 50)

# Appearance
zstyle ':battery-prompt:' icon '🔋'                 # discharging icon
zstyle ':battery-prompt:' icon_charging '⚡'         # charging icon
zstyle ':battery-prompt:' color_low '#ff5555'      # at or below threshold_low
zstyle ':battery-prompt:' color_high '#f1fa8c'     # at or below threshold_high
zstyle ':battery-prompt:' color_charging '#50fa7b' # while charging (always shown)
```

## Manual placement

Leave `show` off and call the function yourself if you want it somewhere else
in the prompt:

```zsh
setopt PROMPT_SUBST
RPROMPT='$(_battery_prompt) %F{8}%*%f'
```

## Fish

Same segment, same defaults, as `fish_right_prompt`. The Fish package
(`MihaiBojin/shell-plugins`, installed with Fisher) ships it, so it owns the
right prompt the way it already owns `fish_prompt`. Off until you ask:

```fish
set -g shell_battery_prompt_show yes   # or -U to persist across sessions
```

Autoloading the function reads no battery; the two checks in front of it return
first unless `show` is set. The reading is cached like the Zsh side
(`shell_battery_prompt_cache_seconds`, default 60), so holding Return does not
fork `pmset` once a prompt.

Configuration is Fish variables rather than `zstyle`, one per Zsh style, read
when the segment renders (except nothing here is read-at-load — Fish has no
load step for it):

```fish
# Display control
set -g shell_battery_prompt_show yes           # enable the segment (default: off)
set -g shell_battery_prompt_show_remaining no  # hide time remaining (default: shown)
set -g shell_battery_prompt_cache_seconds 0    # cache for N seconds (default: 60, 0 disables)

# Thresholds — the segment appears only at or below threshold_high
set -g shell_battery_prompt_threshold_low 25   # red at or below this (default: 25)
set -g shell_battery_prompt_threshold_high 50  # yellow at or below this (default: 50)

# Appearance — colours are set_color hex, with or without a leading '#'
set -g shell_battery_prompt_icon '🔋'
set -g shell_battery_prompt_icon_charging '⚡'
set -g shell_battery_prompt_color_low ff5555
set -g shell_battery_prompt_color_high f1fa8c
set -g shell_battery_prompt_color_charging 50fa7b
```

`show` accepts `1`, `yes`, `true` or `on`; anything else is off. `show_remaining`
is on unless set to `0`, `no`, `false` or `off`.

Want it somewhere other than the far right? Leave `show` off and call the
renderer yourself from a `fish_right_prompt` — or any prompt — of your own:

```fish
function fish_right_prompt
    _shell_battery_prompt
    date '+%H:%M'
end
```

## Requirements

- macOS: `pmset` (part of the system).
- Linux: `/sys/class/power_supply/BAT0`.
- Anywhere else the segment is simply empty.
