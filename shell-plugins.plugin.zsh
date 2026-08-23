#
# shell-plugins — the "load everything" entry point.
#
# Antidote finds this at the repository root, so a bundle line of
#
#     MihaiBojin/shell-plugins
#
# loads every first-party Zsh plugin below, in the order written here.
#
# To pick features individually instead — which is what a configuration that
# cares about load order should do — declare them one at a time and never touch
# this file:
#
#     MihaiBojin/shell-plugins path:zsh/plugins/prompt
#     MihaiBojin/shell-plugins path:zsh/plugins/git-worktree
#
# Both modes are supported and always will be.
#
# The list below is written out by hand on purpose: no globbing, no `find`, no
# external commands, nothing discovered at startup. Adding a plugin means
# adding a line.
#
# Order only matters in one place: battery-prompt appends to RPROMPT and prompt
# clears it, so prompt comes first. The rest are independent of each other.
#

() {
  local _sp_plugins=${${(%):-%x}:A:h}/zsh/plugins

  source $_sp_plugins/prompt/prompt.plugin.zsh
  source $_sp_plugins/battery-prompt/battery-prompt.plugin.zsh

  source $_sp_plugins/dns/dns.plugin.zsh
  source $_sp_plugins/eternal-terminal/eternal-terminal.plugin.zsh
  source $_sp_plugins/git-alias/git-alias.plugin.zsh
  source $_sp_plugins/git-worktree/git-worktree.plugin.zsh
  source $_sp_plugins/macos/macos.plugin.zsh
}
