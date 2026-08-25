#!/usr/bin/env zsh
#
# Behavioural tests for the git-alias branch commands, which need real
# repositories to say anything useful. Run with `zsh -f` so nothing depends on a
# personal .zshrc:
#
#     zsh -f tests/zsh/git-alias.zsh
#
# git's own configuration is isolated too: a global commit.gpgsign, hooks, or an
# init.defaultBranch would otherwise decide whether these pass.
#

emulate -L zsh
setopt no_unset

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

typeset -g ROOT=${${(%):-%x}:A:h:h:h}
typeset -g PASS=0 FAIL=0
typeset -ga SANDBOXES=()

ok()   { (( PASS++ )); print -r  -- "  ok    $1" }
bad()  { (( FAIL++ )); print -ru2 -- "  FAIL  $1"; [[ -n ${2-} ]] && print -ru2 -- "        $2" }
eq()   { [[ $2 == $3 ]] && ok "$1" || bad "$1" "expected [$2], got [$3]" }
has()  { [[ $3 == *$2* ]] && ok "$1" || bad "$1" "[$3] does not contain [$2]" }
group(){ print -r -- ""; print -r -- "$1" }

cleanup() { local s; for s in $SANDBOXES; do rm -rf $s; done }
trap cleanup EXIT

source $ROOT/zsh/plugins/git-alias/git-alias.plugin.zsh

# One repository, one branch per way a branch can end.
local root=$(mktemp -d)
SANDBOXES+=( $root )
local bs=$root/branches

git init -q --initial-branch=main $bs
cd $bs
{
  git commit -q --allow-empty -m base

  git checkout -q -b merged
  echo a >a; git add a; git commit -q -m a
  git checkout -q main
  git merge -q --no-ff merged -m 'merge merged'

  git checkout -q -b squashed main
  echo b >b; git add b; git commit -q -m b
  git checkout -q main
  git merge -q --squash squashed
  git commit -q -m 'squash b'

  git checkout -q -b alone main
  echo c >c; git add c; git commit -q -m c
  git checkout -q main
  git branch twin alone

  git checkout -q -b nowhere main
  echo d >d; git add d; git commit -q -m d
  git checkout -q main
} >/dev/null 2>&1

group 'branch state'

has 'a merged branch says so' 'merged into main' "$(_git_alias_branch_state merged)"
has 'a squashed branch is recognised by content' 'squash-merged into main' "$(_git_alias_branch_state squashed)"
has 'a branch another ref holds says which' 'same commit as twin' "$(_git_alias_branch_state alone)"
has 'a branch that is nowhere else says so' 'not in main' "$(_git_alias_branch_state nowhere)"

_git_alias_branch_state merged >/dev/null;   eq 'merged exits 0' 0 $?
_git_alias_branch_state squashed >/dev/null; eq 'squash-merged exits 0' 0 $?
_git_alias_branch_state alone >/dev/null;    eq 'held by another ref exits 0' 0 $?
_git_alias_branch_state nowhere >/dev/null;  eq 'unreferenced exits 1' 1 $?

group 'gbd'

gbd --force main 2>/dev/null
eq 'gbd will not delete the default branch' 1 $?
has 'main survives' ' main' "$(git branch)"

git checkout -q nowhere
gbd --force nowhere 2>/dev/null
eq 'gbd will not delete the branch you are on' 1 $?
git checkout -q main

gbd --force squashed >/dev/null
eq 'gbd deletes a squash-merged branch' 0 $?
eq 'and it is gone' '' "$(git branch --list squashed)"

group 'gb'

eq 'gb --list is git branch' "$(git branch)" "$(gb --list)"
gb -h 2>/dev/null >/dev/null
eq 'gb -h exits 0' 0 $?

cd $ROOT
print -r -- ""
print -r -- "  $PASS passed, $FAIL failed"
(( FAIL == 0 ))
