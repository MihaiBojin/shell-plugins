#
# git-alias — the short git and GitHub CLI commands, and the helpers they need.
#
# The set is what actually gets typed, not a catalogue. ohmyzsh's git plugin
# has three hundred of them and is linked from the README; this is the handful
# that earn their keep, defined here so the collection can stand on its own.
# Two `gh` aliases ride along at the bottom, for the same reason.
#
# Aliases, plus gwip and gunwipall, which are loops rather than lines.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )

# Claim the two names something else may already hold, so that loading this
# after ohmyzsh's git plugin means what it looks like it means.
#
# Zsh resolves a command as alias, then function, then builtin, then binary. So
# ohmyzsh's `alias gwip` hides our function no matter which loaded last, and
# `autoload -Uz` is a no-op on a name that is already a defined function, which
# leaves its `gunwipall` in place. Neither is a clash zsh reports; both are
# silent, and both were live in a configuration that loaded the two plugins.
#
# 2>/dev/null because unalias and unfunction fail loudly on a name that was
# never there, which is the normal case.
unalias gwip 2>/dev/null
unfunction gunwipall 2>/dev/null

autoload -Uz gwip gunwipall gb gbd gnb \
  _git_alias_current_branch _git_alias_main_branch \
  _git_alias_say _git_alias_branch_pick _git_alias_branch_state

# Add, commit, amend
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias 'gca!'='git commit --verbose --all --amend'
alias 'gcan!'='git commit --verbose --all --no-edit --amend'

# Move about. gcm goes to whatever this repository calls its default branch,
# asked at the moment you run it rather than guessed.
#
# gb and gbd are not here: they open a picker, and there is nothing readable for
# an alias to expand to. They are functions, autoloaded above. `gb --list` is
# the plain `git branch` this used to be. Nor is gnb, which fetches before it
# branches and puts the name in the middle of the command rather than at the
# end.
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcm='git checkout $(_git_alias_main_branch)'
alias gst='git status'

# Look
alias gd='git diff'
alias gdca='git diff --cached'

# Cherry-pick, and the two ways out of one
alias gcp='git cherry-pick'
alias gcpc='git cherry-pick --continue'
alias gcpa='git cherry-pick --abort'

# Push. gpsup is the first push of a new branch; the rest is the usual one.
alias gp='git push'
alias gpsup='git push --set-upstream origin $(_git_alias_current_branch)'

# Merge the default branch in, whatever it is called here
alias gmom='git merge origin/$(_git_alias_main_branch)'

# Park work in a commit that says it is not finished, and take it back out.
# gunwipall undoes a whole run of them; see functions/gunwipall.
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'

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
