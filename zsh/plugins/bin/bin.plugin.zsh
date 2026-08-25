#
# bin — put the repository's own executables on $PATH.
#
#   battery    the charge, once, when you ask for it
#   macos      provisioning helpers for setting a Mac up
#
# These are bash scripts rather than shell functions because nothing in them
# touches the shell: they print and exit. One implementation then serves Zsh
# and Fish both, which is why they are not in `functions/` and not autoloaded.
#
# Appended rather than prepended: a command of your own that happens to share a
# name keeps winning. Nothing else in this repository writes to $PATH — that is
# your configuration's business — but a plugin that ships commands has to make
# them reachable, and there is no `fpath` equivalent for an executable.
#
# Fish gets the same directory from one line in config.fish, because Fisher
# only ever copies functions/, conf.d/, completions/ and themes/:
#
#   fish_add_path ~/git/MihaiBojin/shell-plugins/bin
#

() {
  local dir=${${(%):-%x}:A:h:h:h:h}/bin
  [[ -d $dir ]] || return 0
  # (I) is the index of the match and 0 when there is none, so this adds the
  # directory once however many times the plugin is sourced. `typeset -U path`
  # would do it too, and would be a change to how the caller's $PATH behaves
  # from then on.
  (( ${path[(Ie)$dir]} )) || path+=( $dir )
}
