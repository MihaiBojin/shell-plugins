#
# git-alias — the short git commands, and the two helpers they need.
#
# The set is what actually gets typed, not a catalogue. ohmyzsh's git plugin
# has three hundred of them and is linked from the README; this is the handful
# that earn their keep, defined here so the collection can stand on its own.
#
# Aliases, plus gwip and gunwipall, which are loops rather than lines.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz gwip gunwipall _git_alias_current_branch _git_alias_main_branch

# Add, commit, amend
alias ga='git add'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias 'gca!'='git commit --verbose --all --amend'
alias 'gcan!'='git commit --verbose --all --no-edit --amend'

# Move about
alias gco='git checkout'
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

# Everything, in one go, for a repository nobody else reads
alias 'gpa!'='git add -A; git commit --message "save all"; git push; git status'
