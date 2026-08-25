#
# battery-prompt — append battery status to RPROMPT when it is worth showing.
#
# Off by default. It is the one thing in this repository that runs a command
# between prompts (`pmset` on macOS, sysfs reads on Linux, roughly 10ms), so
# it has to be asked for:
#
#   zstyle ':battery-prompt:' show yes
#
# See README.md for the rest of the styles.
#

fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz _battery_prompt

# Cache, shared across prompts, so a fast typist doesn't fork pmset per key.
typeset -g _battery_prompt_cache_time=0
typeset -g _battery_prompt_cache_output=
typeset -g _battery_prompt_cache_seconds=60

# Nothing below runs unless zsh/zutil is already loaded, and that is not a
# guess: `zstyle` is a builtin from that module, so a style can only exist if
# something already loaded it. No module, no styles, nothing to ask — and the
# defaults are already in place.
#
# Worth the test. Loading zsh/zutil costs about 3.5ms, which is more than
# everything else in this repository put together, and this plugin is off
# unless asked for. A shell that never turns it on should not pay for the
# module that would have said so.
if zmodload -e zsh/zutil; then
  zstyle -s ':battery-prompt:' cache_seconds _battery_prompt_cache_seconds ||
    _battery_prompt_cache_seconds=60

  # `zstyle -t` is false unless the style is explicitly true, which is the
  # point: nothing here should start polling a battery because a plugin got
  # loaded.
  if zstyle -t ':battery-prompt:' show; then
    # A parameter expansion, not a command substitution. Both need
    # PROMPT_SUBST, but zsh expands ${...} itself where $(...) forks a subshell
    # before every prompt -- about 13ms on every command you run.
    #
    # _battery_prompt leaves its rendering in _battery_prompt_cache_output, so
    # the hook only has to call it and the prompt only has to read the variable.
    setopt PROMPT_SUBST

    autoload -Uz add-zsh-hook
    _battery_prompt_precmd() { _battery_prompt > /dev/null }
    add-zsh-hook precmd _battery_prompt_precmd

    RPROMPT="${RPROMPT:+${RPROMPT} }"'${_battery_prompt_cache_output}'

    # The right prompt sits on the same row as the command, so copying that row
    # out of the scrollback takes the battery reading with it. TRANSIENT_RPROMPT
    # erases it from the line as soon as that line is accepted: only the prompt
    # you are typing at carries the segment, and everything above it is the
    # command on its own.
    #
    #   zstyle ':battery-prompt:' transient no
    #
    # leaves it on every line, which is zsh's default.
    if ! zstyle -T ':battery-prompt:' transient; then
      unsetopt TRANSIENT_RPROMPT
    else
      setopt TRANSIENT_RPROMPT
    fi
  fi
fi
