#!/usr/bin/env fish
#
# Behavioural tests for the Fish git-worktree commands, which need real
# repositories to say anything useful. Run with --no-config so nothing here
# depends on a personal config.fish:
#
#     fish --no-config tests/fish/git-worktree.fish
#
# git's own configuration is isolated too: a global commit.gpgsign, hooks or an
# init.defaultBranch would otherwise decide whether these pass.

set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_SYSTEM /dev/null
set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t

set -g ROOT (path resolve (status dirname)/../..)
set -g PASS 0
set -g FAIL 0
set -g SANDBOXES

set -p fish_function_path $ROOT/functions

function ok
    set -g PASS (math $PASS + 1)
    echo "  ok    $argv[1]"
end

function bad
    set -g FAIL (math $FAIL + 1)
    echo "  FAIL  $argv[1]" >&2
    set -q argv[2]; and echo "        $argv[2]" >&2
    return 0
end

function eq -a desc expected actual
    test "$expected" = "$actual"; and ok $desc; or bad $desc "expected [$expected], got [$actual]"
end

function has -a desc needle haystack
    string match --quiet "*$needle*" -- "$haystack"; and ok $desc
    or bad $desc "[$haystack] does not contain [$needle]"
end

function hasnt -a desc needle haystack
    string match --quiet "*$needle*" -- "$haystack"; and bad $desc "[$haystack] contains [$needle]"
    or ok $desc
end

function group
    echo
    echo $argv[1]
end

# A repository with a real remote, and one branch per interesting case.
# Prints the sandbox root.
function fixture
    set -l root (path resolve (mktemp -d))
    set -ga SANDBOXES $root
    begin
        git init -q --bare --initial-branch=main $root/origin/demo.git

        git init -q --initial-branch=main $root/seed
        git -C $root/seed commit -q --allow-empty -m base
        git -C $root/seed remote add origin $root/origin/demo.git
        git -C $root/seed push -q -u origin main
        rm -rf $root/seed

        git clone -q $root/origin/demo.git $root/parent/demo
    end >/dev/null 2>&1
    echo $root
end

function cleanup
    for s in $SANDBOXES
        rm -rf $s
    end
end

# ------------------------------------------------------------------ paths
group 'paths'
set -l root (fixture)
set -l repo $root/parent/demo
cd $repo

eq 'the worktree root sits beside the repository' "$root/parent/.worktrees" (_gw_wt_dir)
eq 'a destination is <root>/<NAME>/<REPO>' "$root/parent/.worktrees/auth/demo" (_gw_dest auth)
eq 'a slash in the branch nests' "$root/parent/.worktrees/fix/login/demo" (_gw_dest fix/login)

# -------------------------------------------------------------------- gwa
group 'gwa'
gwa auth >/dev/null 2>&1
eq 'gwa cds into the new worktree' "$root/parent/.worktrees/auth/demo" (path resolve $PWD)
eq 'gwa creates the branch' auth (git rev-parse --abbrev-ref HEAD)
eq 'the branch does not track the base' '' (git rev-parse --abbrev-ref --symbolic-full-name 'auth@{upstream}' 2>/dev/null)

cd $repo
set -l out (gwa auth 2>&1)
has 'a second gwa says the worktree is already there' 'already exists' "$out"
eq 'and cds to it' "$root/parent/.worktrees/auth/demo" (path resolve $PWD)

cd $repo
set out (gwa auth/deeper 2>&1)
hasnt 'a branch whose name collides with an existing ref creates nothing' 'Preparing worktree (new branch' ''
eq 'and nothing is created' 0 (count (path filter -d $root/parent/.worktrees/auth/deeper 2>/dev/null))

# The collision the layout can produce on its own: a sibling repository under
# the same parent has a worktree exactly where this repository's branch wants
# its own directory.
git init -q --initial-branch=main $root/parent/login
git -C $root/parent/login commit -q --allow-empty -m base
git -C $root/parent/login worktree add -q $root/parent/.worktrees/fix/login -b fix 2>/dev/null
cd $repo
set out (gwa fix/login 2>&1)
has 'a nesting collision with another repository is refused' 'would nest inside it' "$out"
has 'and it names the repository in the way' login "$out"
eq 'and nothing is created there' 0 (count (path filter -d $root/parent/.worktrees/fix/login/demo 2>/dev/null))

cd $repo
gwa feature/oauth >/dev/null 2>&1
eq 'a slashed branch nests on disk' "$root/parent/.worktrees/feature/oauth/demo" (path resolve $PWD)

cd $repo
set out (gwa 'bad..name' 2>&1)
has 'an invalid branch name is refused' 'invalid branch name' "$out"

# -------------------------------------------------------------------- gwl
group 'gwl'
set -l listed (_gw_records | string split \t -f3 | string join ' ')
has 'the listing knows the auth worktree' auth "$listed"
has 'the listing knows the main checkout' main "$listed"

# --------------------------------------------------------- the predicate
group 'what counts as finished'
set -l root2 (fixture)
set -l repo2 $root2/parent/demo

git -C $repo2 checkout -q -b ordinary main
echo ordinary >$repo2/ordinary.txt
git -C $repo2 add ordinary.txt
git -C $repo2 commit -q -m ordinary
git -C $repo2 checkout -q main
git -C $repo2 merge -q --no-ff -m merge ordinary

git -C $repo2 checkout -q -b squashed main
echo squashed >$repo2/squashed.txt
git -C $repo2 add squashed.txt
git -C $repo2 commit -q -m squashed
git -C $repo2 checkout -q main
git -C $repo2 merge -q --squash squashed >/dev/null 2>&1
git -C $repo2 commit -q -m 'squashed, as one commit'

git -C $repo2 checkout -q -b unmerged main
echo unmerged >$repo2/unmerged.txt
git -C $repo2 add unmerged.txt
git -C $repo2 commit -q -m unmerged
git -C $repo2 checkout -q main

# The head branch is origin/main, so the merges have to reach the remote before
# anything counts as finished — which is also true of the real thing.
git -C $repo2 push -q origin main

_gw_merged_reason ordinary origin/main $repo2
eq 'an ordinary merge is seen' merged "$_gw_reply"
_gw_merged_reason squashed origin/main $repo2
eq 'a squash merge is seen' squash-merged "$_gw_reply"
if _gw_merged_reason unmerged origin/main $repo2
    bad 'an unmerged branch is not finished' "said [$_gw_reply]"
else
    ok 'an unmerged branch is not finished'
end

# -------------------------------------------------------------------- gwr
group 'gwr'
cd $repo2
git worktree add -q $root2/parent/.worktrees/ordinary/demo ordinary 2>/dev/null
git worktree add -q $root2/parent/.worktrees/unmerged/demo unmerged 2>/dev/null

set out (echo y | gwr $root2/parent/.worktrees/ordinary/demo 2>&1)
has 'a merged branch is removed' 'removed ordinary' "$out"
has 'and the branch is deleted' 'deleted branch ordinary' "$out"
has 'with the way back printed' 'restore: git branch ordinary' "$out"
eq 'the checkout is gone' 0 (count (path filter -d $root2/parent/.worktrees/ordinary/demo 2>/dev/null))
if git -C $repo2 show-ref --verify --quiet refs/heads/ordinary
    bad 'the branch is gone'
else
    ok 'the branch is gone'
end

set out (echo y | gwr $root2/parent/.worktrees/unmerged/demo 2>&1)
has 'an unmerged branch is refused' 'not merged into main' "$out"
has 'and says how to override' 'gwr --force' "$out"
if git -C $repo2 show-ref --verify --quiet refs/heads/unmerged
    ok 'the unmerged branch survives'
else
    bad 'the unmerged branch survives'
end

set out (gwr --force $root2/parent/.worktrees/unmerged/demo 2>&1)
has '--force removes the checkout' removed "$out"
has 'and keeps the branch' 'branch unmerged kept' "$out"
if git -C $repo2 show-ref --verify --quiet refs/heads/unmerged
    ok 'the branch is still there after --force'
else
    bad 'the branch is still there after --force'
end

# --------------------------------------------------------------- gwr --all
group 'gwr --all'
set -l root3 (fixture)
set -l repo3 $root3/parent/demo

git -C $repo3 checkout -q -b squashed main
echo squashed >$repo3/squashed.txt
git -C $repo3 add squashed.txt
git -C $repo3 commit -q -m squashed
git -C $repo3 checkout -q main
git -C $repo3 merge -q --squash squashed >/dev/null 2>&1
git -C $repo3 commit -q -m 'squashed, as one commit'

git -C $repo3 checkout -q -b keeper main
echo keeper >$repo3/keeper.txt
git -C $repo3 add keeper.txt
git -C $repo3 commit -q -m keeper
git -C $repo3 checkout -q main
git -C $repo3 push -q origin main

cd $repo3
git worktree add -q $root3/parent/.worktrees/squashed/demo squashed 2>/dev/null
git worktree add -q $root3/parent/.worktrees/keeper/demo keeper 2>/dev/null

set out (gwr --all 2>&1)
has 'the dry run would remove the squashed branch' 'would remove' "$out"
has 'and says why' squash-merged "$out"
has 'the unfinished one is skipped with a reason' 'not merged into main' "$out"
has 'and it tells you how to go through with it' -- '--yes' "$out"
eq 'the dry run removes nothing' 1 (count (path filter -d $root3/parent/.worktrees/squashed/demo))

group 'refusals'
# Standing inside a worktree, so the main checkout is refused for being the
# main checkout rather than for being underfoot.
cd $root3/parent/.worktrees/keeper/demo
set out (gwr --all 2>&1)
has 'the worktree you are standing in is skipped' 'standing in' "$out"
has 'and so is the main worktree' 'is the main worktree' "$out"

cd $repo3
echo dirty >$root3/parent/.worktrees/squashed/demo/scratch.txt
set out (gwr --all 2>&1)
has 'a dirty worktree is skipped' 'uncommitted changes' "$out"
rm $root3/parent/.worktrees/squashed/demo/scratch.txt

set out (gwr --all --yes 2>&1)
has '--yes removes the finished one' 'removed squashed' "$out"
eq 'and its checkout is gone' 0 (count (path filter -d $root3/parent/.worktrees/squashed/demo 2>/dev/null))
eq 'the unfinished one stays' 1 (count (path filter -d $root3/parent/.worktrees/keeper/demo))
if git -C $repo3 show-ref --verify --quiet refs/heads/keeper
    ok 'and so does its branch'
else
    bad 'and so does its branch'
end

# --------------------------------------------------------- picker preview
group 'picker preview'

# The preview pane runs `git -C` against one field of the line. The field shown
# to a human has $HOME shortened to ~, and nothing expands a tilde inside an
# argument fzf hands to a shell, so pointing the preview there makes git say
# `cannot change to '~/x'` on every keystroke — invisible, because a preview
# that errors looks the same as a preview with nothing to show.
#
# So stand in for fzf and look at what it was handed.
set -l root4 (fixture)
set -l repo4 $root4/parent/demo
cd $repo4
git -C $repo4 worktree add -q $root4/parent/.worktrees/probe/demo -b probe >/dev/null 2>&1

set -l fake (path resolve (mktemp -d))
set -ga SANDBOXES $fake
echo '#!/bin/sh
cat > "$FAKE_FZF_LINES"
head -1 "$FAKE_FZF_LINES"' >$fake/fzf
chmod +x $fake/fzf

set -l seen $fake/lines
begin
    set -lx PATH $fake $PATH
    set -lx FAKE_FZF_LINES $seen
    _gw_pick 'worktree>' '' >/dev/null
end

set -l bad 0
set -l count 0
for line in (cat $seen)
    set count (math $count + 1)
    set -l last (string split \t -- $line)[-1]
    test -d "$last"; or set bad (math $bad + 1)
end
eq 'the picker offered every worktree' 2 $count
eq 'the preview field is a real directory on every line' 0 $bad

set -l src (string join ' ' (cat $ROOT/functions/_gw_pick.fish))
has 'the preview reads the last field' '{-1}' (string match -r -- "--preview='[^']*'" $src)

cd /
cleanup
echo
echo "  $PASS passed, $FAIL failed"
test $FAIL -eq 0
