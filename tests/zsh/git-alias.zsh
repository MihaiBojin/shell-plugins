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
skip() { print -r  -- "  skip  $1" }

# A real pty, so a picker gated on `[[ -t 0 ]]` takes its fzf path. python3 is
# on both CI runners and is only ever used here; without it the assertion that
# needs a terminal is skipped rather than passing for the wrong reason.
have_tty_runner() { (( $+commands[python3] )) }

with_tty() {
  local dir=$1 body=$2
  python3 -c '
import pty, sys, os
def rd(fd):
    return os.read(fd, 1024)
pty.spawn([sys.argv[1], "-f", "-c", sys.argv[2]], rd)
' zsh "source ${(q)ROOT}/zsh/plugins/git-alias/git-alias.plugin.zsh
cd ${(q)dir} || exit 1
$body" >/dev/null 2>&1
}

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

group 'the branch picker wants a terminal'

# fzf with a redirected stdin draws its full-screen UI over the terminal and
# waits for a key that cannot arrive, so the picker reaches for it only when
# there is one. The worktree pickers ask the same question.
cd $bs
git branch -q pick/one main 2>/dev/null
git branch -q pick/two main 2>/dev/null

tfake=$(mktemp -d); SANDBOXES+=( $tfake )
print -r -- '#!/bin/sh
echo ran >> "$TFZF_MARKER"
head -1' > $tfake/fzf
chmod +x $tfake/fzf
export TFZF_DIR=$tfake TFZF_MARKER=$tfake/marker

( path=( $TFZF_DIR $path ); _git_alias_branch_pick 'b>' '' </dev/null >/dev/null 2>&1 )
eq 'the branch picker gives up rather than opening fzf blind' 1 $?
eq 'and never ran it' 0 "$(grep -c . $TFZF_MARKER 2>/dev/null || print 0)"

if have_tty_runner; then
  rm -f $TFZF_MARKER
  with_tty $bs 'path=( $TFZF_DIR $path )
    _git_alias_branch_pick "b>" "" >/dev/null 2>&1'
  eq 'with a terminal it reaches for it' 1 "$(grep -c . $TFZF_MARKER 2>/dev/null || print 0)"
else
  skip 'with a terminal it reaches for it (no python3 for a pty)'
fi

group 'gnb'

# A server, a clone of it, and a commit pushed after the clone. Branching from
# the local main would miss that commit; branching from origin/main does not,
# which is the whole point of the command.
local server=$(mktemp -d)/server.git
SANDBOXES+=( ${server:h} )
git init -q --bare --initial-branch=main $server
local seed=$(mktemp -d)/seed
SANDBOXES+=( ${seed:h} )
git init -q --initial-branch=main $seed
git -C $seed commit -q --allow-empty -m base
git -C $seed remote add origin $server
git -C $seed push -q origin main

local clone=$(mktemp -d)/clone
SANDBOXES+=( ${clone:h} )
git clone -q $server $clone 2>/dev/null

git -C $seed commit -q --allow-empty -m ahead
git -C $seed push -q origin main
local tip=$(git -C $seed rev-parse HEAD)

cd $clone
local stale=$(git rev-parse main)

gnb >/dev/null 2>&1
eq 'gnb with no name exits 2' 2 $?
gnb one two >/dev/null 2>&1
eq 'gnb with two names exits 2' 2 $?
gnb 'not a branch' >/dev/null 2>&1
eq 'gnb refuses an invalid branch name' 2 $?
gnb main >/dev/null 2>&1
eq 'gnb refuses a name that is already a branch' 1 $?
eq 'and leaves you where you were' main "$(_git_alias_current_branch)"

gnb feat/oauth >/dev/null 2>&1
eq 'gnb exits 0' 0 $?
eq 'and checks the new branch out' feat/oauth "$(_git_alias_current_branch)"
eq 'starting at what the server has' $tip "$(git rev-parse HEAD)"
eq 'not at the local copy of the default branch' $stale "$(git rev-parse main)"
eq 'and tracking nothing, so git pull cannot reach for main' '' "$(git config --get branch.feat/oauth.merge)"

has 'a name already taken says what checks it out' 'gb feat/oauth' "$(gnb feat/oauth 2>&1 >/dev/null)"

cd ${clone:h}
gnb anything >/dev/null 2>&1
eq 'gnb outside a repository exits 1' 1 $?

group 'which remote'

local multi=$(mktemp -d)/multi
SANDBOXES+=( ${multi:h} )
git init -q --initial-branch=main $multi
git -C $multi commit -q --allow-empty -m base
local up=$(mktemp -d)/up.git
SANDBOXES+=( ${up:h} )
local fork=$(mktemp -d)/fork.git
SANDBOXES+=( ${fork:h} )
git init -q --bare --initial-branch=develop $up
git init -q --bare --initial-branch=main $fork

cd $multi
git remote add upstream $up
git push -q upstream main:develop
eq 'one remote needs no configuration at all' upstream "$(_git_alias_remote)"

git remote add fork $fork
git push -q fork main
git fetch -q --all
git remote set-head upstream --auto >/dev/null 2>&1
git remote set-head fork --auto >/dev/null 2>&1

# Neither is called origin, and nothing has been configured yet.
git config --unset branch.main.remote 2>/dev/null
eq 'with two remotes and nothing said, the first is taken' "$(git remote | head -1)" "$(_git_alias_remote)"

git config checkout.defaultRemote upstream
eq 'checkout.defaultRemote decides' upstream "$(_git_alias_remote)"
git config --unset checkout.defaultRemote

git config branch.main.remote fork
eq 'branch.<current>.remote decides' fork "$(_git_alias_remote)"

# remote.pushDefault is the push target and must not move the base.
git config remote.pushDefault upstream
eq 'remote.pushDefault does not decide the base' fork "$(_git_alias_remote)"
eq 'but it does decide the push target' upstream "$(_git_alias_push_remote)"
# git's own precedence: branch.<name>.pushRemote wins over remote.pushDefault.
git config branch.main.pushRemote fork
eq 'branch.<current>.pushRemote overrides it, as git-config says' fork "$(_git_alias_push_remote)"
git config --unset branch.main.pushRemote
git config --unset remote.pushDefault
eq 'unset, the push target is the base remote' fork "$(_git_alias_push_remote)"

eq 'the default branch comes from that remote' main "$(_git_alias_main_branch)"
eq 'and each remote advertises its own' develop "$(_git_alias_main_branch upstream)"

gnb feat/from-fork >/dev/null 2>&1
eq 'gnb branches off the resolved remote' "$(git rev-parse refs/remotes/fork/main)" "$(git rev-parse HEAD)"
git checkout -q main

git config branch.main.remote upstream
gnb feat/from-upstream >/dev/null 2>&1
eq 'and follows the configuration when it changes' "$(git rev-parse refs/remotes/upstream/develop)" "$(git rev-parse HEAD)"

cd $ROOT
print -r -- ""
print -r -- "  $PASS passed, $FAIL failed"
(( FAIL == 0 ))
