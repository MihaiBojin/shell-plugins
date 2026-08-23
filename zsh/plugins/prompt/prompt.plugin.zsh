#
# prompt — a minimal, two-line, Pure-like prompt.
#
#   <blank line>
#   ~/some/directory
#   ❯
#
# The whole prompt is one native prompt-expansion string: no precmd hooks, no
# ZLE hooks, no VCS queries, no subprocesses, no async workers, and nothing
# that has to be recomputed between commands. Zsh renders it entirely on its
# own, so a prompt costs no forks at all.
#
# The chevron is magenta after a command that succeeded and red after one that
# failed — %(?..) is zsh's own "was the last status zero" ternary.
#

# PROMPT_PERCENT is on by default; assert it because everything below depends
# on it, and a plugin has to work when it is sourced by itself.
setopt PROMPT_PERCENT

# Zsh marks a partial last line with an inverse '%' before redrawing. Pure
# hides it, and so do we: the prompt already starts with a blank line.
PROMPT_EOL_MARK=''

PROMPT=$'\n%F{blue}%~%f\n%(?.%F{magenta}❯.%F{red}❯)%f '

# Deliberately empty: this plugin owns the right-hand prompt, so switching to
# it from another theme leaves nothing behind. Plugins that want to add to
# RPROMPT (battery-prompt, for one) must load *after* this one.
RPROMPT=''

# Not set on purpose:
#
#   PROMPT_SUBST   nothing here is a command substitution.
#   precmd/preexec no timing, no title updates, no git status.
#   PS2/PS3/PS4    left at the shell's defaults, which are already fine.
