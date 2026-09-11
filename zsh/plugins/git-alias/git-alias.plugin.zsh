#
# git-alias — the short git and GitHub CLI commands, and the helpers they need.
#
# The set is what actually gets typed, not a catalogue. ohmyzsh's git plugin
# has three hundred of them and is linked from the README; this is the handful
# that earn their keep, defined here so the collection can stand on its own.
# Two `gh` aliases ride along at the bottom, for the same reason.
#
# Aliases, plus functions: the gb! and gbd! pickers, and gcm, gcm! and gup,
# which print the command they are about to run.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )

autoload -Uz 'gb!' 'gbd!' gcm 'gcm!' gup \
  _git_alias_current_branch _git_alias_main_branch \
  _git_alias_remote _git_alias_push_remote \
  _git_alias_say _git_alias_announce _git_alias_colour \
  _git_alias_branch_pick _git_alias_branch_state

# Add, commit, amend
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias 'gca!'='git commit --verbose --all --amend'
alias 'gcan!'='git commit --verbose --all --no-edit --amend'

# Move about. gcm goes to whatever this repository calls its default branch,
# asked at the moment you run it rather than guessed, and is a function
# autoloaded above: an alias expands to a fixed string, so the branch it reached
# could only be read after the checkout. gcm! is gcm and gup in one command.
#
# gb is git branch itself, so `gb -d name`, `gb -a` and every other flag pass
# through. The picker that fuzzy-finds a branch and checks it out is `gb!`,
# following the convention the `!` names come from: the plain name is git's, the
# banged one is ours. gbd! is a function too, autoloaded above: a picker has
# nothing readable for an alias to expand to.
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gst='git status'

# Look
alias gd='git diff'
alias gdca='git diff --cached'

# Cherry-pick, and the two ways out of one
alias gcp='git cherry-pick'
alias gcpc='git cherry-pick --continue'
alias gcpa='git cherry-pick --abort'

# Push. gpsup is the first push of a new branch; the rest is the usual one.
# The remote is remote.pushDefault when it is set, which is what makes a fork
# checkout work: branch from upstream, push to the fork. Unset, it falls back to
# the remote the repository belongs to.
alias gp='git push'
alias gpsup='git push --set-upstream $(_git_alias_push_remote) $(_git_alias_current_branch)'

# Fetch. --prune is explicit rather than left to fetch.prune, so the alias means
# the same thing in a repository whose configuration says otherwise.
alias gfa='git fetch --all --tags --prune --jobs=10'

# Catch this branch up with the default branch, whatever it is called here and
# wherever this repository's remote is: merge it in, or replay onto it. Either
# can stop on a conflict, so either has a --continue and an --abort. The names
# are ohmyzsh's, where the `om` is a literal origin; here it is the remote the
# branch belongs to.
alias gmom='git merge $(_git_alias_remote)/$(_git_alias_main_branch)'
alias gmc='git merge --continue'
alias gma='git merge --abort'
alias grbom='git rebase $(_git_alias_remote)/$(_git_alias_main_branch)'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'

# Everything, in one go, for a repository nobody else reads. gcap stops at the
# first failure; gpa! does not, so a rejected commit still pushes.
alias 'gpa!'='git add -A; git commit --message "save all"; git push; git status'
alias gcap='git add -A && git commit --message "CommitAndPush" && git push && git status'

# GitHub CLI. Not git, but the same two commands every new machine needs before
# git works with GitHub at all, so they live here rather than in a plugin of
# their own. $HOME is single-quoted so it resolves when you run the alias, not
# when the plugin loads.
alias gh-login="gh auth login -p ssh -h github.com --skip-ssh-key -s 'repo,admin:public_key,write:org'"
alias gh-add-key='gh ssh-key add "$HOME"/.ssh/id_ed25519.pub --type authentication'
