#
# git-worktree — fzf-driven helpers for git worktrees.
#
#   gw, gwh                               this help
#   gwl [QUERY]                           pick a worktree and cd into it
#   gwa [--fetch|--no-fetch] NAME [BASE]  add a worktree on branch NAME, and cd
#                                         into it
#   gwr [--force] [PATH|QUERY]            remove a worktree whose branch is
#                                         finished, and the branch with it
#
# Worktrees live beside the repository they belong to, at
# <PARENT>/.worktrees/<NAME>/<REPO>. Every command works on the repository you
# are standing in. See README.md for configuration.
#
# Loading this costs no forks and reads no function bodies: everything below is
# autoloaded on first use.
#

# Where this plugin lives, so the help can point at its README. %x is the file
# being sourced; $0 would be the function name once we are inside one.
typeset -g _GW_DIR=${${(%):-%x}:A:h}

fpath=( $_GW_DIR/functions $_GW_DIR/completions $fpath )

# Shared by the helpers, which are separate autoloaded files and so cannot pass
# these between themselves. Namespaced to keep the global scope tidy.
typeset -g _GW_RESET=$'\e[0m' _GW_DIM=$'\e[2m' _GW_BOLD=$'\e[1m'
typeset -g _GW_RED=$'\e[31m' _GW_YELLOW=$'\e[33m' _GW_CYAN=$'\e[36m'
typeset -g _GW_GREEN=$'\e[32m'

autoload -Uz \
  gw gwl gwa gwm gwr \
  _gw_choose _gw_confirm _gw_default_branch \
  _gw_dest _gw_err _gw_forge_kind _gw_forge_load _gw_forge_slug \
  _gw_forge_state _gw_full_ref \
  _gw_ignored_paths _gw_in_repo _gw_info _gw_is_merged _gw_list _gw_main_worktree \
  _gw_merged_reason _gw_nap _gw_owns _gw_pick _gw_pick_branch _gw_plain_list _gw_records _gw_remote \
  _gw_remote_has_branch _gw_remote_head _gw_rmdir_up \
  _gw_prune_upto _gw_run _gw_squash_merged _gw_stashes_for \
  _gw_suggest_prune _gw_unpushed_count _gw_usage _gw_warn \
  _gw_work_in_progress _gw_worktree_of_branch _gw_wt_dir

alias gwh='gw'

# Completion is registered by dropping completions/ on $fpath above; the
# consuming configuration runs compinit once, afterwards.
#
# When compinit has *already* run — an older .zshrc that initializes completion
# before loading plugins — it never saw those files, so wire them up by hand.
#
# $_comps is the assoc array compinit builds, so its existence is exactly "has
# compinit run". $+functions[compdef] would answer the same question most of
# the time, but it reads the `functions` parameter, which pulls in the
# zsh/parameter module — a few tenths of a millisecond, paid by every shell
# that loads this plugin whether or not it ever runs a gw command. It is also
# the less precise test: a framework that stubs compdef ahead of compinit makes
# it true early.
if (( $+_comps )); then
  autoload -Uz _gwa _gwl _gwm _gwr _gw_branches _gw_worktree_paths
  compdef _gwa gwa
  compdef _gwl gwl
  compdef _gwm gwm
  compdef _gwr gwr
fi
