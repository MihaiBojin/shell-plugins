#!/usr/bin/env zsh
#
# Behavioural tests for the git-worktree plugin, which needs real repositories
# to say anything useful. Run with `zsh -f` so nothing depends on a personal
# .zshrc:
#
#     zsh -f tests/zsh/git-worktree.zsh
#
# git's own configuration is isolated too: a global commit.gpgsign, hooks, or
# an init.defaultBranch would otherwise decide whether these pass.
#

emulate -L zsh
setopt no_unset

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

typeset -g ROOT=${${(%):-%x}:A:h:h:h}
typeset -g PLUGIN=$ROOT/zsh/plugins/git-worktree/git-worktree.plugin.zsh
typeset -g PASS=0 FAIL=0
typeset -ga SANDBOXES=()

ok()   { (( PASS++ )); print -r  -- "  ok    $1" }
bad()  { (( FAIL++ )); print -ru2 -- "  FAIL  $1"; [[ -n ${2-} ]] && print -ru2 -- "        $2" }
eq()   { [[ $2 == $3 ]] && ok "$1" || bad "$1" "expected [$2], got [$3]" }
has()  { [[ $3 == *$2* ]] && ok "$1" || bad "$1" "[$3] does not contain [$2]" }
hasnt(){ [[ $3 != *$2* ]] && ok "$1" || bad "$1" "[$3] should not contain [$2]" }
group(){ print -r -- ""; print -r -- "$1" }

cleanup() { local s; for s in $SANDBOXES; do rm -rf $s; done }
trap cleanup EXIT

# A repository with one worktree per interesting case, and a real remote to
# compare against. Prints the sandbox root.
fixture() {
  emulate -L zsh
  local root b x repo

  root=$(mktemp -d)
  SANDBOXES+=( $root )

  # Everything git says goes to a log rather than stdout: `merge --squash`
  # reports on stdout even under -q, and this function's stdout is the path.
  {
    git init -q --bare --initial-branch=main $root/origin/demo.git

    git init -q --initial-branch=main $root/seed
    git -C $root/seed commit -q --allow-empty -m base
    git -C $root/seed remote add origin $root/origin/demo.git
    git -C $root/seed push -q -u origin main
    rm -rf $root/seed

    git clone -q $root/origin/demo.git $root/parent/demo
    repo=$root/parent/demo

    # One branch per case, all forked from the base commit.
    for b in squashed ordinary unmerged dirty stashed untracked undone; do
      git -C $repo checkout -q -b $b main
      print -r -- "$b" > $repo/$b.txt
      git -C $repo add -A
      git -C $repo commit -q -m "$b"
      git -C $repo checkout -q main
    done

    # undone takes its own change back, so it contributes nothing — but it
    # also never picked up what main did next, so its patch is not upstream.
    git -C $repo checkout -q undone
    git -C $repo rm -q undone.txt
    git -C $repo commit -q -m "undo it all"
    git -C $repo checkout -q main

    # squashed lands on the remote as one commit; ordinary as a real merge.
    git -C $repo merge -q --squash squashed
    git -C $repo commit -q -m "squash: squashed"
    git -C $repo merge -q --no-ff ordinary -m "merge ordinary"
    git -C $repo push -q origin main
    git -C $repo fetch -q origin

    # same-tree branches off the finished main and adds an empty commit: not an
    # ancestor of it, and yet its tree is main's tree exactly.
    git -C $repo checkout -q -b same-tree main
    git -C $repo commit -q --allow-empty -m "nothing at all"
    git -C $repo checkout -q main

    for b in squashed ordinary unmerged dirty stashed untracked undone same-tree; do
      git -C $repo worktree add -q $root/parent/.worktrees/$b/demo $b
    done
    git -C $repo worktree add -q --detach $root/parent/.worktrees/loose/demo

    # dirty: a tracked file modified. untracked: a file never added.
    print -r -- changed >> $root/parent/.worktrees/dirty/demo/dirty.txt
    print -r -- forgotten > $root/parent/.worktrees/untracked/demo/new-work.txt

    # stashed: work parked against that branch.
    print -r -- wip >> $root/parent/.worktrees/stashed/demo/stashed.txt
    git -C $root/parent/.worktrees/stashed/demo stash push -q -m parked
  } > $root/fixture.log 2>&1

  # The log is kept either way; a broken fixture shows up as failures below
  # with somewhere to look.
  [[ -d $root/parent/demo/.git || -f $root/parent/demo/.git ]] || {
    print -ru2 -- "fixture failed; see $root/fixture.log"
    return 1
  }
  print -r -- $root
}

# Run zsh code with the plugin loaded, in $1, merging stderr into stdout with
# the colour stripped so assertions read plainly.
#
# `cd || exit` is not defensive padding. Without it, a fixture that failed to
# build leaves $dir empty or wrong, `cd` fails, and the test body runs in
# whatever directory the suite was started from — which is a git repository,
# and one of these cases commits. Ask how I know.
in_repo() {
  local dir=$1; shift
  [[ -n $dir && -d $dir ]] || {
    print -ru2 -- "in_repo: no such directory: [$dir]"
    return 1
  }
  zsh -f -c "
    zstyle ':git-worktree:' spinner no
    source $PLUGIN
    cd ${(q)dir} || exit 1
    $1
  " 2>&1 | sed $'s/\033\\[[0-9;]*h//g;s/\033\\[[0-9;]*m//g'
}

#
# 1. Telling a finished branch from an unfinished one.
#
group "merge detection"
local sb out repo
sb=$(fixture) || { print -ru2 -- "cannot build a fixture; giving up"; exit 1 }
repo=$sb/parent/demo

out=$(in_repo $repo 'local REPLY; _gw_merged_reason squashed origin/main && print -r -- $REPLY')
eq "a squash-merged branch is recognised" "squash-merged" "$out"

out=$(in_repo $repo 'local REPLY; _gw_merged_reason ordinary origin/main && print -r -- $REPLY')
eq "a branch merged the ordinary way says so" "merged" "$out"

out=$(in_repo $repo 'local REPLY; _gw_merged_reason unmerged origin/main; print -r -- "rc=$? reply=[$REPLY]"')
eq "an unmerged branch is not mistaken for a squash-merged one" "rc=1 reply=[]" "$out"

out=$(in_repo $repo 'local REPLY; _gw_merged_reason same-tree origin/main && print -r -- $REPLY')
eq "a branch whose tree is already the head branch's is finished" "squash-merged" "$out"

# The conservative half of the same idea: undone gives its own change back, but
# never picked up what main did after it, so `git cherry` will not call its
# patch upstream. Keeping it is the safe answer.
out=$(in_repo $repo 'local REPLY; _gw_merged_reason undone origin/main; print -r -- "rc=$?"')
eq "a branch that undid itself but lags the head branch is kept" "rc=1" "$out"

out=$(in_repo $repo 'local wt='"$sb"'/parent/.worktrees/squashed/demo
  print -r -- more >> $wt/squashed.txt
  git -C $wt add -A
  git -C $wt commit -q -m "after the squash"
  local REPLY; _gw_merged_reason squashed origin/main; print -r -- "rc=$?"')
eq "a branch squash-merged and then added to is unmerged again" "rc=1" "$out"

# No upstream means unknown, not zero. gwa creates branches with --no-track,
# so this is the normal state for the ones this plugin makes, and answering
# zero would disarm the "commits nobody pushed" guard for exactly those.
out=$(in_repo $repo '_gw_unpushed_count unmerged; print -r -- "rc=$?"')
eq "a branch with no upstream answers unknown, not zero" "rc=1" "$out"

out=$(in_repo $repo 'git push -q -u origin unmerged 2>/dev/null
  local n=$(_gw_unpushed_count unmerged); print -r -- "$n rc=$?"')
eq "and counts properly once it has one" "0 rc=0" "$out"

#
# 2. The refusals.
#
group "refusals"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo 'gwr --all --no-fetch')
has "the worktree you are standing in is refused"  "main — is the worktree you are standing in" "$out"
has "a detached HEAD is refused"                   "(detached) — has a detached HEAD" "$out"
has "a tracked modification is work"               "dirty — has uncommitted changes" "$out"
has "an untracked file is work too"                "untracked — has uncommitted changes" "$out"
has "a stash parked on the branch is work"         "stashed — has a stash entry parked on it" "$out"
has "an unmerged branch is left alone, and says why" "unmerged — not merged into main" "$out"

out=$(in_repo $sb/parent/.worktrees/unmerged/demo 'gwr --all --no-fetch')
has "the main worktree is refused from elsewhere" "main — is the main worktree" "$out"
has "standing inside a worktree refuses that one" "unmerged — is the worktree you are standing in" "$out"

out=$(in_repo $repo 'git worktree lock '"$sb"'/parent/.worktrees/squashed/demo
  gwr --all --no-fetch')
has "a locked worktree is refused" "squashed — is locked" "$out"

#
# 3. gwr --all end to end.
#
group "gwr --all"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo 'gwr --all --no-fetch')
has "the dry run says what it would remove" "would remove squashed — squash-merged into main" "$out"
has "and what it would leave"               "skip         unmerged — not merged into main" "$out"
has "and how to go through with it"         "re-run with --yes to do it" "$out"

out=$(in_repo $repo 'gwr --all --no-fetch >/dev/null 2>&1; git worktree list --porcelain | grep -c "^worktree "')
eq "a dry run removes nothing" "10" "$out"

sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'gwr --all --no-fetch --yes >/dev/null 2>&1
  print -rl -- '"$sb"'/parent/.worktrees/*(N:t) | sort | tr "\n" " "')
eq "--yes removes exactly the finished worktrees" "dirty loose stashed undone unmerged untracked " "$out"

sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'gwr --all --no-fetch --yes >/dev/null 2>&1; git branch --list --format="%(refname:short)" | sort | tr "\n" " "')
eq "every finished branch goes with its worktree" \
   "dirty main stashed undone unmerged untracked " "$out"

# There is no flag to ask for: a squash-merged branch, which git itself calls
# unmerged, goes with its worktree because check 2 proved otherwise.
sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'gwr --all --no-fetch --yes >/dev/null 2>&1
  git branch --list --format="%(refname:short)" | sort | tr "\n" " "')
eq "squash-merged branches go too, with no flag to ask for it" \
   "dirty main stashed undone unmerged untracked " "$out"

out=$(in_repo $repo 'gwr --all --no-fetch --yes 2>&1 | grep -c "re-run with --force"')
eq "and nothing tells you to re-run with a flag" "0" "$out"

# The escape hatch is recovery, not prevention: one line per branch, so any
# one of them can be put back on its own.
sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'gwr --all --no-fetch --yes 2>&1 | grep -c "^    restore: git branch "')
eq "every deleted branch prints its own way back" "3" "$out"

sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'local line=$(gwr --all --no-fetch --yes 2>&1 | grep "restore: git branch squashed" | head -1)
  local before=$(git rev-parse --short squashed 2>/dev/null)
  eval "${line#*restore: }"
  print -r -- "gone before restore: [$before] back at: $(git rev-parse --short squashed 2>/dev/null)"')
has "and the line it prints really does put it back" "gone before restore: [] back at: " "$out"

out=$(in_repo $repo 'print -rl -- '"$sb"'/parent/.worktrees/*(N:t) | sort | tr "\n" " "')
eq "the directories left empty over a removed worktree go with it" \
   "dirty loose stashed undone unmerged untracked " "$out"

sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(in_repo $repo 'gwr --all --no-fetch --branch unmerged')
eq "--branch looks at that branch and no other" \
   "  skip         unmerged — not merged into main
gw: nothing is finished; 1 left alone" "$out"

# --dry-run wins over --yes whichever order they arrive in, in both shells.
out=$(in_repo $repo 'local before=$(git worktree list --porcelain | grep -c "^worktree ")
  gwr --all --no-fetch --yes --dry-run >/dev/null 2>&1
  local after=$(git worktree list --porcelain | grep -c "^worktree ")
  [[ $before == $after ]] && print -r -- same || print -r -- "$before -> $after"')
eq "--yes --dry-run removes nothing" "same" "$out"

out=$(in_repo $repo 'local before=$(git worktree list --porcelain | grep -c "^worktree ")
  gwr --all --no-fetch --dry-run --yes >/dev/null 2>&1
  local after=$(git worktree list --porcelain | grep -c "^worktree ")
  [[ $before == $after ]] && print -r -- same || print -r -- "$before -> $after"')
eq "and neither does the other order" "same" "$out"

out=$(in_repo $repo 'gwr --all --no-fetch --branch nosuch; print -r -- "rc=$?"')
has "--branch on a branch with no worktree is an error" "no worktree of this repository has branch 'nosuch'" "$out"
has "and exits non-zero" "rc=1" "$out"

out=$(in_repo $repo 'gwr --all extra-arg 2>&1; print -r -- "rc=$?"')
has "a positional argument is refused, with the fix" "did you mean: gwr --all --branch extra-arg" "$out"

out=$(in_repo $repo 'gwr --all --branch 2>&1; print -r -- "rc=$?"')
has "--branch without a name is refused" "--branch needs a name" "$out"

out=$(in_repo $repo 'gw' )
has "the sweep is in the help" "--all " "$out"

#
# 4. gwr — the single-target case of the same predicate.
#
group "gwr"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(print -r -- n | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/ordinary/demo')
has "the prompt says the branch is finished, and how" \
    "branch ordinary — merged into main; it will be deleted" "$out"
has "and answering no does nothing" "aborted" "$out"

out=$(in_repo $repo 'git branch --list --format="%(refname:short)" ordinary')
eq "answering no really did nothing" "ordinary" "$out"

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/ordinary/demo
  print -r -- "left: $(git branch --list --format="%(refname:short)" ordinary)"')
has "a merged branch is deleted, and says which check fired" \
    "deleted branch ordinary (was " "$out"
has "naming the reason with it" "— merged into main" "$out"
has "and it is really gone" "left: " "$out"

# git branch -d refuses a squash-merged branch; -D is right there and nowhere
# else, and the prompt said so before anything happened.
out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/squashed/demo
  print -r -- "left: $(git branch --list --format="%(refname:short)" squashed)"')
has "a squash-merged branch is deleted too" \
    "deleted branch squashed (was " "$out"

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/same-tree/demo 2>&1 |
  grep "restore: git branch"')
has "gwr prints the way back too" "restore: git branch same-tree " "$out"

out=$(in_repo $repo 'gwr --keep-branch /nowhere 2>&1; print -r -- "rc=$?"')
has "there is no --keep-branch to reach for" "unknown option: --keep-branch" "$out"

#
# An unfinished worktree is where unfinished work lives: refused outright.
#
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/unmerged/demo; print -r -- "rc=$?"')
has "an unmerged worktree is refused"      "not removing" "$out"
has "and says why"                         "branch unmerged — not merged into main" "$out"
has "and how to override it"               "gwr --force" "$out"
has "and says the branch survives that"    "the branch is kept" "$out"
hasnt "and never reaches the prompt"       "Proceed?" "$out"
has "and exits non-zero"                   "rc=1" "$out"

out=$(in_repo $repo 'print -rl -- '"$sb"'/parent/.worktrees/*(N:t) | grep -c unmerged')
eq "the refused worktree is still there" "1" "$out"

out=$(print -r -- y | in_repo $repo 'gwr --force '"$sb"'/parent/.worktrees/unmerged/demo
  print -r -- "left: $(git branch --list --format="%(refname:short)" unmerged)"')
has "--force removes it anyway"     "--force: removing it anyway" "$out"
has "and keeps the branch"          "left: unmerged" "$out"
out=$(in_repo $repo 'print -rl -- '"$sb"'/parent/.worktrees/*(N:t) | grep -c "^unmerged$"')
eq "and the worktree is gone" "0" "$out"

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/dirty/demo; print -r -- "rc=$?"')
has "uncommitted changes are refused before anything else" "has uncommitted changes" "$out"
has "and exit non-zero" "rc=1" "$out"

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/stashed/demo; print -r -- "rc=$?"')
has "a stash parked on the branch is refused" "has a stash entry parked on it" "$out"

out=$(print -r -- y | in_repo $repo 'gwr '"$sb"'/parent/.worktrees/loose/demo; print -r -- "rc=$?"')
has "a detached worktree has nothing to prove finished" "has a detached HEAD" "$out"
has "so it is refused too" "rc=1" "$out"

out=$(print -r -- y | in_repo $repo 'gwr --force '"$sb"'/parent/.worktrees/loose/demo; print -r -- "rc=$?"')
hasnt "but --force removes it" "not removing" "$out"

# Locked is the one refusal --force does not cover.
sb=$(fixture) || exit 1; repo=$sb/parent/demo
out=$(print -r -- y | in_repo $repo 'git worktree lock '"$sb"'/parent/.worktrees/ordinary/demo
  gwr --force '"$sb"'/parent/.worktrees/ordinary/demo; print -r -- "rc=$?"')
has "a locked worktree is refused even with --force" "is locked — unlock it first" "$out"
has "and exits non-zero" "rc=1" "$out"

# A worktree can have the head branch checked out; removing it is fine,
# deleting main is not.
out=$(print -r -- y | in_repo $repo 'git worktree add -q --detach '"$sb"'/parent/.worktrees/head/demo origin/main
  git -C '"$sb"'/parent/.worktrees/head/demo switch -q -c spare-main origin/main
  git -C '"$sb"'/parent/.worktrees/head/demo branch -f keepme 2>/dev/null
  gwr '"$sb"'/parent/.worktrees/head/demo')
hasnt "a merged non-head branch is not confused with the head branch" "it is the head branch" "$out"

out=$(print -r -- y | in_repo $repo 'gwr --force '"$sb"'/parent/.worktrees/undone/demo >/dev/null 2>&1
  [[ -d '"$sb"'/parent/.worktrees/undone ]] && print -r -- "left behind" || print -r -- "cleaned up"')
eq "the directory left empty over the worktree goes with it" "cleaned up" "$out"

# The paths handed to _gw_rmdir_up come from different places — one you typed,
# one git printed — and on macOS that is /var/... against /private/var/...,
# the same directory under two names. :a would not resolve that; :A does.
out=$(in_repo $repo 'local root=$(mktemp -d)
  mkdir -p $root/keep/go/away
  # $root as typed, and the same path resolved: exactly the mismatch gwr hits.
  _gw_rmdir_up $root/keep/go/away ${root:A}/keep
  [[ -d $root/keep/go ]] && print -r -- "left behind" || print -r -- "cleaned up"
  rm -rf $root')
eq "an unresolved path and a resolved stop still match" "cleaned up" "$out"

#
# 4b. The directory is the branch name, slashes and all.
#
group "nested branch names"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo '_gw_dest auth')
eq "a plain name is the directory" "${sb:A}/parent/.worktrees/auth/demo" "$out"

out=$(in_repo $repo '_gw_dest fix/login')
eq "a slash nests rather than flattening" \
   "${sb:A}/parent/.worktrees/fix/login/demo" "$out"

out=$(in_repo $repo '_gw_dest feature/oauth/v2')
eq "and so does every slash" \
   "${sb:A}/parent/.worktrees/feature/oauth/v2/demo" "$out"

# The directory name is whatever git left, a trailing `.git` included. Trimming
# it would send a worktree somewhere the companion `origin` CLI does not look,
# and the two agreeing about the path without being told is the point of
# deriving it.
git clone -q $sb/origin/demo.git $sb/parent/bare.git 2>/dev/null
out=$(in_repo $sb/parent/bare.git '_gw_dest auth')
eq "a checkout named <name>.git keeps the suffix" \
   "${sb:A}/parent/.worktrees/auth/bare.git" "$out"

out=$(in_repo $repo 'gwa --no-fetch fix/login >/dev/null 2>&1
  print -r -- "${PWD##*/.worktrees/} on $(git rev-parse --abbrev-ref HEAD)"')
eq "gwa lands there, directory name equal to branch name" \
   "fix/login/demo on fix/login" "$out"

out=$(in_repo $repo 'gwa --no-fetch fix/login >/dev/null 2>&1; print -r -- "${PWD##*/.worktrees/}"')
eq "asking again just cds there" "fix/login/demo" "$out"

out=$(in_repo $repo 'gwa --no-fetch fix/login >/dev/null 2>&1
  cd '"$repo"'
  print -r -- y | gwr --force '"${sb}"'/parent/.worktrees/fix/login/demo >/dev/null 2>&1
  [[ -d '"${sb}"'/parent/.worktrees/fix ]] && print -rn -- "left " || print -rn -- "gone "
  print -r -- "and the caller can still print"')
eq "removal takes the whole empty nest, and does not break the caller's stdout" \
   "gone and the caller can still print" "$out"

#
# Nesting means one branch's worktree can be another branch's parent directory:
# branch `fix` in a repository called `login` occupies <root>/fix/login, and so
# does branch `fix/login`. git says only "already exists" for one direction and
# silently nests a worktree inside another for the other, so both are caught.
#
group "a worktree and a parent directory wanting the same path"

pair_fixture() {
  emulate -L zsh
  local root r
  root=$(mktemp -d)
  SANDBOXES+=( $root )
  for r in demo login; do
    git init -q --initial-branch=main $root/parent/$r >/dev/null 2>&1
    git -C $root/parent/$r commit -q --allow-empty -m base
  done
  print -r -- $root
}

local pair
pair=$(pair_fixture) || exit 1

out=$(in_repo $pair/parent/login 'gwa --no-fetch fix >/dev/null 2>&1; print -r -- "${PWD##*/.worktrees/}"')
eq "branch fix in a repo called login takes <root>/fix/login" "fix/login" "$out"

out=$(in_repo $pair/parent/demo 'gwa --no-fetch fix/login; print -r -- "rc=$?"')
has "so fix/login from a sibling repo is refused" "would nest inside it" "$out"
has "naming the repository that owns the ancestor" "/parent/login — " "$out"
has "and says what to do about it" "not a prefix of it" "$out"
has "and exits non-zero" "rc=1" "$out"

pair=$(pair_fixture) || exit 1

out=$(in_repo $pair/parent/demo 'gwa --no-fetch fix/login >/dev/null 2>&1; print -r -- "${PWD##*/.worktrees/}"')
eq "the other way round: fix/login goes first" "fix/login/demo" "$out"

out=$(in_repo $pair/parent/login 'gwa --no-fetch fix; print -r -- "rc=$?"')
has "and then branch fix in the repo called login is refused" \
    "already exists and is not empty" "$out"
has "and exits non-zero too" "rc=1" "$out"

# The same question — who owns this directory — asked of a worktree that is
# already sitting at the path we want. With the root derived, two repositories
# cannot normally collide, so this one is made by hand: exactly what a moved
# repository, or a worktree somebody added themselves, leaves behind.
#
# _gw_records cannot answer it: the squatter is another repository's worktree,
# so this repository has never heard of it.
twin_fixture() {
  emulate -L zsh
  local root p
  root=$(mktemp -d)
  SANDBOXES+=( $root )
  for p in a b; do
    git init -q --initial-branch=main $root/$p/demo >/dev/null 2>&1
    git -C $root/$p/demo commit -q --allow-empty -m "base of $p" >/dev/null 2>&1
  done
  # repo b plants a worktree exactly where repo a's `gwa auth` would go
  git -C $root/b/demo worktree add -q -b auth $root/a/.worktrees/auth/demo >/dev/null 2>&1
  print -r -- $root
}

local twin
twin=$(twin_fixture) || exit 1

out=$(in_repo $twin/a/demo 'gwa --no-fetch auth
  print -r -- "rc=$? pwd=${PWD:t}"')
has "a worktree belonging to another repository is named as such" \
    "is a worktree of" "$out"
has "and what to do about it" "move it, or pick a name" "$out"
eq "and gwa leaves you where you started, not in the other repository" \
   "rc=1 pwd=demo" "${${(f)out}[-1]}"

# Without the check this printed "worktree already exists", exited 0, and
# cd-ed into the other repository's checkout, where the next commit would have
# gone to the wrong repository.
out=$(in_repo $twin/b/demo 'gwa --no-fetch auth >/dev/null 2>&1
  print -r -- "rc=$? $(git log -1 --format=%s)"')
eq "while the repository that owns it is simply taken there" \
   "rc=0 base of b" "$out"

sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo 'gwa --no-fetch a >/dev/null 2>&1
  cd '"$repo"'
  gwa --no-fetch a/demo/b; print -r -- "rc=$?"')
has "an ancestor that is one of our own worktrees names the branch" \
    "this repository's worktree for 'a'" "$out"
has "and refuses" "rc=1" "$out"

# Left to git, that second one does not fail at all — it nests a worktree
# inside the directory holding another branch's.
out=$(in_repo $pair/parent/login 'git worktree add '"$pair"'/parent/.worktrees/fix/login 2>&1 | head -1')
has "which git alone would have gone ahead and done" "Preparing worktree" "$out"

#
# 4c. Things that look like the answer but are not.
#
group "mistaken identity"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

# git resolves a bare name as a tag before a branch, so a tag and a branch
# sharing a name make every revision question answer about the tag.
out=$(in_repo $repo 'git tag unmerged main
  local REPLY; _gw_merged_reason unmerged origin/main; print -r -- "rc=$?"')
eq "a tag of the same name does not answer for the branch" "rc=1" "$out"

# gh and glab take -R OWNER/REPO and nothing else. Without one they answer
# about whatever repository the shell is in, which for `gwr <path>` is
# somebody else's — so no name means the forge is not asked at all.
out=$(in_repo $repo 'git remote set-url origin https://gitlab.com/acme/platform/api.git
  _gw_forge_slug origin')
eq "a gitlab subgroup is a name, not a path" "acme/platform/api" "$out"

out=$(in_repo $repo 'git remote set-url origin git@github.com:o/r.git; _gw_forge_slug origin')
eq "and so is the ordinary shape" "o/r" "$out"

out=$(in_repo $repo 'git remote set-url origin '"$sb"'/origin/demo.git
  _gw_forge_slug origin; print -r -- "rc=$?"')
eq "a local path is not a name, so nothing is asked" "rc=1" "$out"

out=$(in_repo $repo 'git remote set-url origin '"$sb"'/origin/demo.git
  _gw_forge_load github origin; print -r -- "rc=$?"')
eq "and the forge check fails closed rather than asking about \$PWD" "rc=1" "$out"

# A wip commit can itself be a merge. A plain log walk crosses into the
# merged-in branch and resets this one onto a commit that was never on it.
sb=$(fixture) || exit 1; repo=$sb/parent/demo
# The dates are pinned, and the side commit is the newer one. Commits made in
# the same second tie-break by parent order, which hands a plain walk the right
# answer by luck and leaves the fix untested.
out=$(in_repo $repo 'source '"$ROOT"'/zsh/plugins/git-alias/git-alias.plugin.zsh
  at() { GIT_AUTHOR_DATE="@$1 +0000" GIT_COMMITTER_DATE="@$1 +0000" git commit -q --allow-empty -m "$2" }
  git checkout -q -b side main
  git checkout -q main
  at 2000 "the commit gunwipall must stop at"
  git checkout -q side
  at 3000 "work on the side branch"
  git checkout -q main
  GIT_AUTHOR_DATE="@4000 +0000" GIT_COMMITTER_DATE="@4000 +0000" \
    git merge -q --no-ff side -m "--wip-- [skip ci]" >/dev/null 2>&1
  gunwipall >/dev/null 2>&1
  git log --max-count=1 --format=%s')
eq "gunwipall stops on this branch, not inside a merged-in one" \
   "the commit gunwipall must stop at" "$out"

#
# 4d. --force where there is nothing to fall back on.
#
group "--force with no branch to keep"

# A detached worktree's commits are reachable from nothing once it goes. There
# is no branch to survive it, so the sha is the only way back.
detached_fixture() {
  emulate -L zsh
  local root
  root=$(mktemp -d)
  SANDBOXES+=( $root )
  {
    git init -q --initial-branch=main $root/r
    git -C $root/r commit -q --allow-empty -m base
    git -C $root/r worktree add -q --detach $root/r/.worktrees/loose/r
    git -C $root/r/.worktrees/loose/r commit -q --allow-empty -m "only this worktree has it"
  } >/dev/null 2>&1
  [[ -e $root/r/.worktrees/loose/r/.git ]] || return 1
  print -r -- $root
}

local det
det=$(detached_fixture) || exit 1

out=$(in_repo $det/r 'gwr '"$det"'/r/.worktrees/loose/r; print -r -- "rc=$?"')
hasnt "a detached worktree is not promised its branch will be kept" "the branch is kept" "$out"
has "it is told what nothing will refer to afterwards" "nothing will refer to" "$out"
has "and given the command that keeps it" "branch NAME " "$out"
has "and refused for now" "rc=1" "$out"

det=$(detached_fixture) || exit 1
out=$(print -r -- y | in_repo $det/r 'gwr --force '"$det"'/r/.worktrees/loose/r')
has "forcing it prints the way back" "restore: git -C " "$out"

# The line is only worth printing if it is exactly runnable.
det=$(detached_fixture) || exit 1
out=$(in_repo $det/r 'local line=$(print -r -- y | gwr --force '"$det"'/r/.worktrees/loose/r 2>&1 |
    sed -n "s/^ *restore: //p")
  eval "${line/NAME/recovered}"
  git log --max-count=1 --format=%s recovered 2>/dev/null')
eq "and running it brings the commit back" "only this worktree has it" "$out"

# `git worktree remove --force` walks past git's own submodule refusal and
# deletes .git/worktrees/<id>/modules/ with the checkout.
submodule_fixture() {
  emulate -L zsh
  local root
  root=$(mktemp -d)
  SANDBOXES+=( $root )
  {
    git init -q --initial-branch=main $root/sub
    git -C $root/sub commit -q --allow-empty -m "the submodule"
    git init -q --initial-branch=main $root/r
    git -C $root/r commit -q --allow-empty -m base
    git -C $root/r -c protocol.file.allow=always submodule add -q $root/sub mod
    git -C $root/r commit -q -m "add the submodule"
    git -C $root/r worktree add -q $root/r-wt -b feat
    git -C $root/r-wt -c protocol.file.allow=always submodule update --init -q
  } >/dev/null 2>&1
  [[ -d $(git -C $root/r-wt rev-parse --absolute-git-dir 2>/dev/null)/modules ]] || return 1
  print -r -- $root
}

local sm
if sm=$(submodule_fixture); then
  out=$(print -r -- y | in_repo $sm/r 'gwr --force '"$sm"'/r-wt; print -r -- "rc=$?"')
  has "a worktree holding submodule git dirs is refused even with --force" \
      "holds submodule git directories" "$out"
  has "and says what to do instead" "worktree remove --force" "$out"
  has "and exits non-zero" "rc=1" "$out"

  out=$(in_repo $sm/r '[[ -d '"$sm"'/r-wt ]] && print -rn -- "worktree kept " || print -rn -- "WORKTREE GONE "
    [[ -d $(git -C '"$sm"'/r-wt rev-parse --absolute-git-dir 2>/dev/null)/modules ]] &&
      print -r -- "and its submodule git dir" || print -r -- "AND ITS SUBMODULE GIT DIR IS GONE"')
  eq "so nothing of the submodule is lost" "worktree kept and its submodule git dir" "$out"
else
  bad "could not build a submodule fixture (git refused a file:// submodule?)"
fi

#
# 5. The git config keys both tools read.
#
group "shared configuration"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo 'git remote add upstream '"$sb"'/origin/demo.git 2>/dev/null
  git config git-worktree-plugin.remote upstream
  _gw_remote')
eq "git-worktree-plugin.remote picks the remote" "upstream" "$out"

# gw.remote was this plugin's own key and is no longer read: one namespace,
# no fallback. `git config --rename-section gw git-worktree-plugin` migrates.
out=$(in_repo $repo 'git remote add upstream '"$sb"'/origin/demo.git 2>/dev/null
  git config --unset-all git-worktree-plugin.remote 2>/dev/null
  git config gw.remote upstream
  _gw_remote')
eq "the retired gw.remote is ignored, not obeyed" "origin" "$out"

out=$(in_repo $repo 'git push -q origin unmerged
  git fetch -q origin
  git config git-worktree-plugin.headBranch unmerged
  _gw_default_branch origin 0 0')
eq "git-worktree-plugin.headBranch overrides the resolution" "origin/unmerged" "$out"

out=$(in_repo $repo 'git config git-worktree-plugin.headBranch trunk
  _gw_default_branch origin 0 0')
eq "and falls back to the bare name when there is no such remote ref" "trunk" "$out"

#
# Where worktrees go is derived, not configured — the one thing both tools
# work out for themselves so they cannot be told different answers.
#
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo '_gw_wt_dir')
eq "the root is .worktrees beside the main checkout" \
   "${sb:A}/parent/.worktrees" "$out"

out=$(in_repo $repo 'git config git-worktree-plugin.worktreeRoot '"$sb"'/elsewhere
  zstyle ":git-worktree:" subdir .wt
  _gw_wt_dir')
eq "and neither the retired git key nor the retired style moves it" \
   "${sb:A}/parent/.worktrees" "$out"

#
# 4. The forge, without touching the network.
#
group "forge"
sb=$(fixture) || exit 1; repo=$sb/parent/demo

out=$(in_repo $repo 'git remote set-url origin git@github.com:o/r.git; _gw_forge_kind origin')
eq "a github remote is recognised" "github" "$out"

out=$(in_repo $repo 'git remote set-url origin https://gitlab.com/o/r.git; _gw_forge_kind origin')
eq "a gitlab remote is recognised" "gitlab" "$out"

out=$(in_repo $repo 'git remote set-url origin /somewhere/local.git; _gw_forge_kind origin; print -r -- "rc=$?"')
eq "a remote that is neither is not guessed at" "rc=1" "$out"

out=$(in_repo $repo 'zstyle ":git-worktree:" forge github; _gw_forge_kind origin')
eq "a style overrides the URL, for self-hosted forges" "github" "$out"

out=$(in_repo $repo 'typeset -g _GW_FORGE_PRS=$(printf "new\tOPEN\t9\nold\tMERGED\t4\nold\tCLOSED\t2\n")
  local REPLY
  _gw_forge_state old && print -r -- $REPLY | tr "\t" " "')
eq "the newest request for a reused branch wins" "MERGED 4" "$out"

out=$(in_repo $repo 'local REPLY; _gw_forge_state nothing-here; print -r -- "rc=$?"')
eq "a branch with no request says so" "rc=1" "$out"

out=$(in_repo $repo 'git remote set-url origin '"$sb"'/origin/demo.git   # an earlier case moved it
  git push -q -u origin unmerged 2>/dev/null
  typeset -g _GW_FORGE_PRS=$(printf "unmerged\tMERGED\t7\n")
  typeset -g _GW_FORGE_NOUN="pull request"
  local REPLY; _gw_is_merged unmerged origin/main main 1; print -r -- "$? $REPLY"')
eq "a merged request retires a branch git cannot see the merge of" \
   "0 its pull request #7 is merged" "$out"

# The same request, on a branch that was never pushed: the request cannot
# speak for commits that have no upstream to have reached.
out=$(in_repo $repo 'typeset -g _GW_FORGE_PRS=$(printf "undone\tMERGED\t8\n")
  typeset -g _GW_FORGE_NOUN="pull request"
  local REPLY; _gw_is_merged undone origin/main main 1; print -r -- "$? $REPLY"')
eq "but not one with no upstream at all" \
   "1 its pull request is merged, but the branch has no upstream to have been pushed to" "$out"

out=$(in_repo $repo 'local wt='"$sb"'/parent/.worktrees/unmerged/demo
  git remote set-url origin '"$sb"'/origin/demo.git   # an earlier case moved it
  git -C $wt push -q -u origin unmerged
  print -r -- later >> $wt/unmerged.txt
  git -C $wt add -A
  git -C $wt commit -q -m "not pushed"
  typeset -g _GW_FORGE_PRS=$(printf "unmerged\tMERGED\t7\n")
  typeset -g _GW_FORGE_NOUN="pull request"
  local REPLY; _gw_is_merged unmerged origin/main main 1; print -r -- "$? $REPLY"')
eq "a merged request does not retire a branch with unpushed work" \
   "1 its pull request is merged, but one commit here is not in it" "$out"

out=$(in_repo $repo 'typeset -g _GW_FORGE_PRS=$(printf "unmerged\tMERGED\t7\n")
  typeset -g _GW_FORGE_NOUN="pull request"
  local REPLY; _gw_is_merged unmerged origin/main main 0; print -r -- "$? $REPLY"')
eq "--no-forge decides from git alone" "1 not merged into main" "$out"

print -r -- ""
print -r -- "git-worktree: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
