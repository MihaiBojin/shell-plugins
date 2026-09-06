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

# Run a fish snippet under a real pty, so a picker gated on `isatty stdin`
# takes its fzf path. The snippet inherits nothing: it sets its own function
# path, the way Fisher's install would.
#
# python3 is on both CI runners and is only ever used here; without it the
# assertions that need a terminal are skipped rather than passing for the
# wrong reason.
function have_tty_runner
    command -q python3
end

function with_tty -d 'Run a fish snippet under a real pty'
    python3 -c '
import pty, sys, os
def rd(fd):
    return os.read(fd, 1024)
pty.spawn([sys.argv[1], "--no-config", "-c", sys.argv[2]], rd)
' (status fish-path) "set -p fish_function_path $ROOT/functions
$argv[1]" >/dev/null 2>&1
end

function skip
    echo "  skip  $argv[1]"
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

# One worktree per way a branch can be unfinished, mirroring the Zsh suite's
# fixture so the two can be compared line for line. Prints the sandbox root.
function fixture_full
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
        set -l repo $root/parent/demo

        for b in squashed unmerged dirty stashed untracked
            git -C $repo checkout -q -b $b main
            echo $b >$repo/$b.txt
            git -C $repo add -A
            git -C $repo commit -q -m $b
            git -C $repo checkout -q main
        end

        # squashed lands on the remote as one commit, so git cannot see the
        # merge and the second check has to.
        git -C $repo merge -q --squash squashed
        git -C $repo commit -q -m 'squash: squashed'
        git -C $repo push -q origin main
        git -C $repo fetch -q origin

        for b in squashed unmerged dirty stashed untracked
            git -C $repo worktree add -q $root/parent/.worktrees/$b/demo $b
        end
        git -C $repo worktree add -q --detach $root/parent/.worktrees/loose/demo

        # dirty: a tracked file modified. untracked: one never added.
        echo changed >>$root/parent/.worktrees/dirty/demo/dirty.txt
        echo forgotten >$root/parent/.worktrees/untracked/demo/new-work.txt

        # stashed: work parked against that branch.
        echo wip >>$root/parent/.worktrees/stashed/demo/stashed.txt
        git -C $root/parent/.worktrees/stashed/demo stash push -q -m parked
    end >$root/fixture.log 2>&1
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

# The directory name is whatever git left, a trailing `.git` included. Trimming
# it would send a worktree somewhere the companion `origin` CLI does not look,
# and the two agreeing about the path without being told is the point of
# deriving it.
git clone -q $root/origin/demo.git $root/parent/bare.git 2>/dev/null
cd $root/parent/bare.git
eq 'a checkout named <name>.git keeps the suffix' "$root/parent/.worktrees/auth/bare.git" (_gw_dest auth)
cd $repo

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

# ------------------------------------------------------- gwa with no NAME
# The set gwl can never show: a branch that exists but has no worktree yet.
# Stand in for fzf, which always prints the query first under --print-query.
set -l bfake (path resolve (mktemp -d))
set -ga SANDBOXES $bfake
echo '#!/bin/sh
cat > "$PICK_LINES"
printf "%s\n" "$PICK_QUERY"
[ -n "$PICK_LINE" ] && sed -n "${PICK_LINE}p" "$PICK_LINES"
exit 0' >$bfake/fzf
chmod +x $bfake/fzf

cd $repo
git -C $repo branch -q nowt main
if have_tty_runner
    with_tty "set -gx PATH $bfake \$PATH
        set -gx PICK_LINES $bfake/lines
        set -gx PICK_QUERY ''
        set -gx PICK_LINE ''
        cd $repo
        _gw_pick_branch 'b>'"
    set -l offered (cat $bfake/lines)
    set -l shown (for l in $offered; string split \t -- $l | tail -1; end)
    has 'the branch picker offers a branch with no worktree' nowt (string join ' ' $shown)
    hasnt 'and not the remote HEAD dressed up as a branch' ' origin ' " "(string join ' ' $shown)" "
else
    skip 'the branch picker offers a branch with no worktree (no python3 for a pty)'
    skip 'and not the remote HEAD dressed up as a branch (no python3 for a pty)'
end

if have_tty_runner
    with_tty "set -gx PATH $bfake \$PATH
        set -gx PICK_LINES $bfake/lines
        set -gx PICK_QUERY ''
        set -gx PICK_LINE 1
        cd $repo
        _gw_pick_branch 'b>'
        echo -n \$_gw_reply > $bfake/reply"
    eq 'picking a line returns the branch, not the display line' 1 (count (string split \t -- (cat $bfake/reply)))
else
    skip 'picking a line returns the branch, not the display line (no python3 for a pty)'
end

if have_tty_runner
    with_tty "set -gx PATH $bfake \$PATH
        set -gx PICK_LINES $bfake/lines
        set -gx PICK_QUERY 'typed-new'
        set -gx PICK_LINE ''
        cd $repo
        _gw_pick_branch 'b>'
        echo -n \$_gw_reply > $bfake/reply"
    eq 'a name that matches nothing is the answer' typed-new (cat $bfake/reply)
else
    skip 'a name that matches nothing is the answer (no python3 for a pty)'
end

# Asked of the picker directly. gwa reaches it through a command substitution,
# and in fish 4.8 anything written to stderr inside one goes to the shell's
# own stderr rather than to a `2>` the caller set up — so `gwa 2>file` catches
# the exit status but not the words.
begin
    set -lx PATH /usr/bin /bin /usr/sbin /sbin
    gwa
    eq 'without fzf, gwa exits 2' 2 $status
    _gw_pick_branch 'b>' 2>$bfake/err >/dev/null
    has 'and still asks for a NAME' 'NAME is required' (cat $bfake/err)
end

# -------------------------------------------------------------------- gwl
group 'gwl'
set -l listed (_gw_records | string split0 | string split (printf '\x1f') -f3 | string join ' ')
has 'the listing knows the auth worktree' auth "$listed"
has 'the listing knows the main checkout' main "$listed"

# --list is the only way to see the set without moving into one of them, and
# the only form that can be piped.
set -l plain (gwl --list)
eq 'gwl --list prints one line per worktree' (count (_gw_records | string split0)) (count $plain)
set -l cols (string split \t -- $plain[1])
eq 'three tab-separated columns' 3 (count $cols)
eq 'and the mark is on the worktree you are standing in' '*' "$cols[1]"
eq 'the third column is a directory' 1 (count (path filter -d $cols[3]))
set -l out (gwl --list extra 2>&1)
has 'gwl --list takes no QUERY' 'takes no QUERY' "$out"

# git ends every --porcelain attribute with a newline, so a directory holding
# one used to arrive as two records for worktrees that do not exist. -z and a
# NUL between records carry the whole path back out.
set -l nl (printf '%s/we\nird' $root/parent | string collect)
git -C $repo worktree add -q -b newline -- $nl 2>/dev/null
set -l recs (_gw_records | string split0)
set -l us (printf '\x1f')
set -l found ''
for r in $recs
    set -l f (string split $us -- $r)
    eq 'every record still has four fields' 4 (count $f)
    test "$f[3]" = newline; and set found $f[1]
end
eq 'a worktree whose path contains a newline survives the parse' "$nl" "$found"
git -C $repo worktree remove --force $nl 2>/dev/null

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
has 'a merged branch is removed' 'removing ordinary — merged into main' "$out"
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
has '--yes removes the finished one' 'removing squashed — squash-merged into main' "$out"
eq 'and its checkout is gone' 0 (count (path filter -d $root3/parent/.worktrees/squashed/demo 2>/dev/null))
eq 'the unfinished one stays' 1 (count (path filter -d $root3/parent/.worktrees/keeper/demo))
if git -C $repo3 show-ref --verify --quiet refs/heads/keeper
    ok 'and so does its branch'
else
    bad 'and so does its branch'
end

# --------------------------------------------------------------------- gwm
group 'gwm'

# Directory name equals branch name, so renaming a branch is a rename and a
# move together. git does neither half of the tidying: the new parent has to
# exist first, and the old one is left behind empty.
set -l rootm (fixture)
set -l repom $rootm/parent/demo
cd $repom
gwa --no-fetch fix/login >/dev/null 2>&1
set -l srcm (path resolve $PWD)
eq 'the worktree starts where its branch says' "$rootm/parent/.worktrees/fix/login/demo" $srcm

echo y | gwm renamed/thing >/dev/null 2>&1
eq 'the branch is renamed' 0 (git -C $repom show-ref --verify --quiet refs/heads/renamed/thing; echo $status)
eq 'the old branch is gone' 1 (git -C $repom show-ref --verify --quiet refs/heads/fix/login; echo $status)
eq 'the checkout moved to match' 1 (count (path filter -d $rootm/parent/.worktrees/renamed/thing/demo))
eq 'and the directories it left behind are gone' 0 (count (path filter -d $rootm/parent/.worktrees/fix 2>/dev/null))

cd $repom
set out (gwm 2>&1)
has 'gwm needs a NEW name' 'NEW is required' "$out"
set out (gwm 'bad..name' 2>&1)
has 'an invalid branch name is refused' 'invalid branch name' "$out"
set out (gwm a b 2>&1)
has 'and only one of them' 'too many arguments' "$out"

cd $rootm/parent/.worktrees/renamed/thing/demo
set out (gwm renamed/thing 2>&1)
has 'renaming a branch to its own name is refused' 'already called that' "$out"
set out (gwm main 2>&1)
has 'and so is a name another branch has' "branch 'main' already exists" "$out"

cd $repom
set out (gwm --force 2>&1)
has 'an unknown flag is refused' 'unknown option' "$out"

# --------------------------------------------------------------- submodules
group 'submodules'

# `git worktree remove --force` walks past git's own submodule refusal and
# deletes .git/worktrees/<id>/modules/* with the checkout. Nothing is printed
# when it does, so the refusal has to happen before the removal runs.
set -l root5 (fixture)
set -l repo5 $root5/parent/demo
git init -q --initial-branch=main $root5/sub
git -C $root5/sub commit -q --allow-empty -m sub

cd $repo5
gwa withsub >/dev/null 2>&1
set -l wt5 (path resolve $PWD)
git -c protocol.file.allow=always submodule add -q $root5/sub vendor >/dev/null 2>&1
git commit -q -m 'add a submodule' >/dev/null 2>&1
set -l moddir (git -C $wt5 rev-parse --absolute-git-dir)/modules

cd $repo5
if test -d $moddir
    ok 'the fixture worktree really holds a submodule git directory'
else
    bad 'the fixture worktree really holds a submodule git directory' "no $moddir"
end

set out (gwr --force $wt5 2>&1)
has 'gwr --force refuses a worktree holding submodule git directories' 'holds submodule git directories' "$out"

has 'and names the command that would do it anyway' 'worktree remove --force' "$out"
eq 'the checkout is still there' 1 (count (path filter -d $wt5 2>/dev/null))
eq 'and so is the submodule git directory' 1 (count (path filter -d $moddir 2>/dev/null))
# The main checkout's git directory holds the whole repository's submodules, so
# asking it the same question would refuse it for a reason that is not true and
# print a command git cannot run.
set out (gwr --force $repo5 2>&1)
hasnt 'and does not say that about the main worktree' 'holds submodule git directories' "$out"
has 'the main worktree is refused outright, not offered a --force' 'refusing to remove the main worktree' "$out"

# ------------------------------------------------------------- the forge check
group 'forge'

# The forge answer travels from _gw_forge_state to _gw_is_finished as two
# tab-separated fields. Fish does not expand \t inside double quotes, so a
# quoted "$a\t$b" would arrive as one field and every branch would come back
# unfinished — silently, since an unfinished branch is the normal answer.
set -l root6 (fixture)
set -l repo6 $root6/parent/demo
git -C $repo6 checkout -q -b forged main
# Real content, and never merged: the two git checks have to fail, or the
# branch qualifies before the forge is ever consulted.
echo forged >$repo6/forged.txt
git -C $repo6 add forged.txt
git -C $repo6 commit -q -m 'work the forge knows about'
git -C $repo6 push -q -u origin forged
git -C $repo6 checkout -q main
# Only now, so the push above could use the real one.
git -C $repo6 remote set-url origin https://github.com/example/demo.git

set -l fake6 (path resolve (mktemp -d))
set -ga SANDBOXES $fake6
echo '#!/bin/sh
printf "forged\tMERGED\t7\nother\tOPEN\t8\n"' >$fake6/gh
chmod +x $fake6/gh

cd $repo6
begin
    set -lx PATH $fake6 $PATH
    set -e _gw_forge_cache_key
    _gw_forge_state forged $repo6
    set -g REPLY6 $_gw_reply
    set -e _gw_forge_cache_key
    _gw_is_finished forged origin/main main 1 $repo6
    set -g FINISHED6 $status
    set -g WHY6 $_gw_reply
end

eq 'the forge answer splits into two fields' 2 (count (string split \t -- $REPLY6))
eq 'the first is the state' MERGED (string split \t -- $REPLY6)[1]
eq 'the second is the number' 7 (string split \t -- $REPLY6)[2]
eq 'a merged pull request finishes a branch git cannot see merged' 0 $FINISHED6
has 'and the reason names the request' 'pull request #7 is merged' "$WHY6"

# ------------------------------------------------------------ the sweep's fetch
group 'gwr --all and the network'

# The sweep judges every branch against the head branch, so it refreshes the
# head branch first. Without that it keeps branches the remote already has.
set -l root7 (fixture)
set -l repo7 $root7/parent/demo

git -C $repo7 checkout -q -b landed main
echo landed >$repo7/landed.txt
git -C $repo7 add landed.txt
git -C $repo7 commit -q -m 'work that lands upstream'
git -C $repo7 push -q origin landed
git -C $repo7 checkout -q main
git -C $repo7 worktree add -q $root7/parent/.worktrees/landed/demo landed 2>/dev/null

# Merge it on the remote, behind this clone's back.
git clone -q $root7/origin/demo.git $root7/other >/dev/null 2>&1
git -C $root7/other merge -q --no-ff -m 'merge landed' origin/landed
git -C $root7/other push -q origin main

cd $repo7
set out (gwr --all --no-fetch 2>&1)
has 'offline, the sweep cannot see the merge' 'not merged into main' "$out"
hasnt 'and says nothing about fetching' fetching "$out"

set out (gwr --all 2>&1)
has 'online, it fetches the head branch first' 'fetching origin/main' "$out"
has 'and then sees the merge' 'would remove' "$out"

set out (gwr --all --fetch 2>&1)
has '--fetch asks for the same thing explicitly' 'fetching origin/main' "$out"

set out (gwr --no-fetch $root7/parent/.worktrees/landed/demo 2>&1)
has 'the single form has no --no-fetch and says where it belongs' '--no-fetch belongs to gwr --all' "$out"

set out (gwr --dry-run $root7/parent/.worktrees/landed/demo 2>&1)
has 'and the message names the flag that was rejected' '--dry-run belongs to gwr --all' "$out"

# Every sweep flag, not just the three about the network: accepted-and-ignored
# is the shape that let --no-fetch mean --no-forge for as long as it did.
for f in --yes --branch=x --fetch
    set out (gwr $f $root7/parent/.worktrees/landed/demo 2>&1)
    has "the single form refuses $f" 'belongs to gwr --all' "$out"
end

# A branch name where --branch belongs: sweeping everything is much more than
# the person asking about one worktree wanted.
set out (gwr --all landed 2>&1)
has 'a positional argument to the sweep is refused' 'takes no positional arguments' "$out"
has 'and it names the flag that was meant' -- '--branch landed' "$out"
eq 'and nothing is swept' 1 (count (path filter -d $root7/parent/.worktrees/landed/demo))

# --no-fetch means offline, and the forge is the one check that needs the
# network. Stand in for gh and count the calls.
set -l fake7 (path resolve (mktemp -d))
set -ga SANDBOXES $fake7
echo '#!/bin/sh
echo called >> "$GH_LOG"' >$fake7/gh
chmod +x $fake7/gh
git -C $repo7 remote set-url origin https://github.com/example/demo.git

begin
    set -lx PATH $fake7 $PATH
    set -lx GH_LOG $fake7/log
    set -e _gw_forge_cache_key
    gwr --all --no-fetch >/dev/null 2>&1
end
eq '--no-fetch asks the forge nothing either' 0 (count (path filter -f $fake7/log 2>/dev/null))

set out (gwr --all --no-fetch --branch nosuch 2>&1)
set -l rc $status
eq '--branch on a branch with no worktree is an error' 1 $rc
has 'and says so' 'no worktree of this repository has branch' "$out"

# --dry-run wins over --yes whichever order they arrive in.
gwr --all --no-fetch --yes --dry-run >/dev/null 2>&1
eq 'the worktree survives --yes --dry-run' 1 (count (path filter -d $root7/parent/.worktrees/landed/demo))
gwr --all --no-fetch --dry-run --yes >/dev/null 2>&1
eq 'and the other order too' 1 (count (path filter -d $root7/parent/.worktrees/landed/demo))

begin
    set -lx git_worktree_fetch no
    set out (gwr --all 2>&1)
end
hasnt 'git_worktree_fetch no keeps the sweep offline' fetching "$out"

# ------------------------------------------------------------- the picker at EOF
group 'the picker at EOF'

# Without fzf the picker reads a number. A failed read is not an empty answer:
# falling through to the [1] default would hand gwr a worktree nobody chose.
set -l root8 (fixture)
set -l repo8 $root8/parent/demo
cd $repo8
git worktree add -q $root8/parent/.worktrees/one/demo -b one >/dev/null 2>&1
git worktree add -q $root8/parent/.worktrees/two/demo -b two >/dev/null 2>&1

set -l picked
set -l rc 0
begin
    set -lx PATH /usr/bin /bin /usr/sbin /sbin
    _gw_pick 'worktree>' '' </dev/null 2>/dev/null
    set rc $status
    set picked $_gw_reply
end
eq 'closed stdin makes the picker fail' 1 $rc
eq 'and it names nothing' '' "$picked"

# ------------------------------------------------- one refusal per kind
group 'every refusal'

# The Zsh suite has covered these since the plugin was written; the Fish half
# had four of them, which is how the submodule refusal and the dead forge check
# both shipped.
set -l rootr (fixture_full)
set -l repor $rootr/parent/demo

cd $repor
set out (gwr --all --no-fetch 2>&1)
has 'the worktree you are standing in is refused' 'main — is the worktree you are standing in' "$out"
has 'a detached HEAD is refused' 'has a detached HEAD' "$out"
has 'a tracked modification is work' 'dirty — has uncommitted changes' "$out"
has 'an untracked file is work too' 'untracked — has uncommitted changes' "$out"
has 'a stash parked on the branch is work' 'stashed — has a stash entry parked on it' "$out"
has 'an unmerged branch is left alone, and says why' 'unmerged — not merged into main' "$out"
has 'and a squash-merged one is offered' 'squashed — squash-merged into main' "$out"

cd $rootr/parent/.worktrees/unmerged/demo
set out (gwr --all --no-fetch 2>&1)
has 'the main worktree is refused from elsewhere' 'main — is the main worktree' "$out"
has 'standing inside a worktree refuses that one' 'unmerged — is the worktree you are standing in' "$out"

cd $repor
git -C $repor worktree lock $rootr/parent/.worktrees/squashed/demo
set out (gwr --all --no-fetch 2>&1)
has 'a locked worktree is refused' 'squashed — is locked' "$out"
set out (gwr --force $rootr/parent/.worktrees/squashed/demo 2>&1)
has 'and --force does not get past a lock either' 'is locked' "$out"
git -C $repor worktree unlock $rootr/parent/.worktrees/squashed/demo

# ------------------------------------------------------ shared configuration
group 'shared configuration'

# The two git config keys are the whole of what a repository can be told, and
# both tools read them from the same place.
set -l rootk (fixture_full)
set -l repok $rootk/parent/demo
cd $repok

git -C $repok remote add upstream $rootk/origin/demo.git 2>/dev/null
git -C $repok config git-worktree-plugin.remote upstream
eq 'git-worktree-plugin.remote picks the remote' upstream (_gw_remote)

# gw.remote was this plugin's own key and is no longer read: one namespace, no
# fallback.
git -C $repok config --unset-all git-worktree-plugin.remote
git -C $repok config gw.remote upstream
eq 'the retired gw.remote is ignored, not obeyed' origin (_gw_remote)

git -C $repok push -q origin unmerged
git -C $repok fetch -q origin
git -C $repok config git-worktree-plugin.headBranch unmerged
eq 'git-worktree-plugin.headBranch overrides the resolution' refs/remotes/origin/unmerged (_gw_head_branch origin 0 $repok)

git -C $repok config git-worktree-plugin.headBranch trunk
eq 'and spells a name with no remote ref under refs/heads/' refs/heads/trunk (_gw_head_branch origin 0 $repok)

# Where worktrees go is derived, not configured — the one thing both tools work
# out for themselves so they cannot be told different answers.
git -C $repok config git-worktree-plugin.worktreeRoot $rootk/elsewhere
set -g git_worktree_subdir .wt
eq 'neither the retired git key nor a variable moves the root' "$rootk/parent/.worktrees" (_gw_wt_dir)
set -e git_worktree_subdir

# ----------------------------------------------- _gw_run captures its command
group '_gw_run captures its command'

# Anything that can reach the network runs through here, so a slow fetch looks
# like work rather than a hang. The half that matters is the capture: git's
# progress used to arrive in the middle of a command's own output.
_gw_run 'a command that works' git --version
eq 'the status is passed through' 0 $status
has 'and the output lands in $_gw_reply' 'git version' "$_gw_reply"

set -l outok (_gw_run 'quiet on success' git --version 2>&1)
hasnt 'a success does not print what the command said' 'git version' "$outok"
has 'it prints a result line instead' 'quiet on success' "$outok"

set -l outbad (_gw_run 'a command that fails' git nosuchsubcommand 2>&1)
set -l rcbad $status
eq 'a failure passes its status through' 1 $rcbad
has 'and a failure does print what the command said' 'not a git command' "$outbad"

# The drift this closes: `git worktree add` reports its progress on stderr, and
# Fish used to let it through into gwa's own output where Zsh collected it.
set -l rootg (path resolve (mktemp -d) | string collect)
set -ga SANDBOXES $rootg
git init -q --initial-branch=main $rootg/parent/demo
git -C $rootg/parent/demo commit -q --allow-empty -m base
cd $rootg/parent/demo
set -l outg (gwa --no-fetch feature 2>&1)
hasnt 'gwa no longer leaks git worktree add progress' 'Preparing worktree' "$outg"
has 'and says what it did instead' "creating 'feature'" "$outg"
cd $rootg/parent/demo

# ------------------------------------------- a newline in a path is carried whole
group 'a newline in a path is carried whole'

# fish splits a command substitution on newlines, so every path that travels
# through one arrives as two list elements when a directory name holds one.
# git allows such a directory, and `git worktree list --porcelain -z` hands it
# back whole, so nothing upstream of these commands truncates it.
set -l rootn (path resolve (mktemp -d) | string collect)
set -ga SANDBOXES $rootn
set -l parentn "$rootn/pa
rent"
set -l repon "$parentn/demo"
git init -q --initial-branch=main "$repon"
git -C "$repon" commit -q --allow-empty -m base

eq 'the main worktree comes back whole' "$repon" (_gw_main_worktree "$repon" | string collect)
eq 'and the worktree root is derived from all of it' "$parentn/.worktrees" (_gw_wt_dir "$repon" | string collect)

cd "$repon"
eq 'and so is the destination for a new branch' "$parentn/.worktrees/feat/demo" (_gw_dest feat | string collect)

set -l recn (_gw_records "$repon" | string split0)
eq 'one worktree is listed, not two' 1 (count $recn)
eq 'and its path is the whole one' "$repon" (string split (printf '\x1f') -- $recn[1])[1]

gwa --no-fetch feat >/dev/null 2>&1
eq 'gwa lands in the right directory' "$parentn/.worktrees/feat/demo" "$PWD"

cd "$repon"

# --------------------------------------- gitignored files are not collateral
group 'gitignored files are not collateral'

# `git worktree remove` deletes gitignored files without --force and without a
# word, and `git status --porcelain` never mentions them — so every refusal
# upstream reads the checkout as clean. They get their own flag. Same spec as
# the Zsh suite.
set -l rooti (fixture_full)
set -l repoi $rooti/parent/demo
set -l wti $rooti/parent/.worktrees/squashed/demo
cd $repoi

# info/exclude rather than a committed .gitignore: the branch has to stay
# exactly as finished as the fixture made it, or this tests the wrong refusal.
echo '.env' >>$repoi/.git/info/exclude
echo secret >$wti/.env

eq 'the checkout still reads as clean' '' (git -C $wti status --porcelain | string collect)
eq 'and the ignored file is what git would take' .env (_gw_ignored_paths $wti)

set -l outi (gwr --no-forge $wti 2>&1 </dev/null | string collect)
has 'with no terminal it refuses rather than deleting them' '--delete-ignored' "$outi"
has 'and names the file it would have taken' '.env' "$outi"
eq 'and the file is still there' secret (cat $wti/.env 2>/dev/null)
eq 'and so is the worktree' yes (test -d $wti; and echo yes; or echo no)

# The sweep never prompts, so it leaves them alone and says why.
set -l outs (gwr --all --yes --no-fetch --no-forge 2>&1 </dev/null | string collect)
has '--all --yes leaves it alone too' '--delete-ignored deletes them' "$outs"
eq 'so the file survives the sweep' secret (cat $wti/.env 2>/dev/null)

# ------------------------------------ a tag cannot impersonate the head branch
group 'a tag cannot impersonate the head branch'

# git resolves refs/tags/ before refs/remotes/, so a tag called `origin/main` is
# what a bare `origin/main` means to merge-base, cherry and ^{tree} — and an
# unmerged branch then reads as merged, at rc 0. Same spec as the Zsh suite.
set -l roots (fixture_full)
set -l repos $roots/parent/demo
cd $repos

# Pointed at a commit that contains the unmerged branch, which is what makes the
# wrong answer look like a right one.
git -C $repos tag origin/main unmerged

# The rest of this group only proves anything while the shadow really shadows.
git -C $repos merge-base --is-ancestor refs/heads/unmerged origin/main 2>/dev/null
eq 'the bare name reads the tag, and calls an unmerged branch merged' 0 $status
git -C $repos merge-base --is-ancestor refs/heads/unmerged refs/remotes/origin/main
eq 'the full ref reads the remote-tracking branch' 1 $status

eq 'so the head branch is resolved to a full ref' refs/remotes/origin/main \
    (_gw_head_branch origin 0 $repos)

set -l heads (_gw_head_branch origin 0 $repos)
_gw_is_finished unmerged $heads main 0 $repos
eq 'and the branch the tag would have retired is still unmerged' 1 $status
has 'and says so' 'not merged into main' "$_gw_reply"

# ----------------------------------------------------- fzf wants a terminal
group 'fzf wants a terminal'

# Both pickers run where a caller may have redirected stdin. fzf with nothing
# to read from draws its full-screen UI over the terminal and waits for a key
# that cannot arrive, so neither reaches for it without a terminal.
set -l roott (fixture)
set -l repot $roott/parent/demo
cd $repot
git -C $repot worktree add -q $roott/parent/.worktrees/one/demo -b one 2>/dev/null

set -l tfake (path resolve (mktemp -d))
set -ga SANDBOXES $tfake
echo '#!/bin/sh
echo ran >> "$TFZF_MARKER"
head -1' >$tfake/fzf
chmod +x $tfake/fzf

begin
    set -lx PATH $tfake $PATH
    set -lx TFZF_MARKER $tfake/marker
    _gw_pick 'w>' '' </dev/null >/dev/null 2>&1
    eq 'gwl picker gives up rather than opening fzf blind' 1 $status
    _gw_pick_branch 'b>' </dev/null >/dev/null 2>&1
    eq 'and the branch picker asks for a NAME instead' 2 $status
end
eq 'neither of them ran fzf' 0 (count (path filter -f $tfake/marker 2>/dev/null))

if have_tty_runner
    with_tty "set -gx PATH $tfake \$PATH
        set -gx TFZF_MARKER $tfake/marker
        cd $repot
        _gw_pick 'w>' ''
        _gw_pick_branch 'b>'"
    eq 'with a terminal they both reach for it' 2 (count (cat $tfake/marker 2>/dev/null))
else
    skip 'with a terminal they both reach for it (no python3 for a pty)'
end

# ------------------------------------------------------------- completions
group 'completions'

# Fish autoloads a completion file the first time you press Tab on that
# command, so these cost nothing at login — but they are only reached through
# $fish_complete_path, which this suite has to set up the way Fisher would.
set -l rootc (fixture)
set -l repoc $rootc/parent/demo
cd $repoc
gwa --no-fetch other >/dev/null 2>&1
cd $repoc

set -l comp "set -p fish_function_path $ROOT/functions; set -p fish_complete_path $ROOT/completions; cd $repoc;"

set -l out (fish --no-config -c "$comp complete -C'gwl '")
has 'gwl completes branch names' other "$out"
set out (fish --no-config -c "$comp complete -C'gwl --'")
has 'and offers --list' --list "$out"

set out (fish --no-config -c "$comp complete -C'gwr '")
has 'gwr completes this repository worktree paths' "$rootc/parent/.worktrees/other/demo" "$out"
set out (fish --no-config -c "$comp complete -C'gwr --all --'")
has 'gwr --all offers --branch' --branch "$out"
has 'and --dry-run' --dry-run "$out"
hasnt 'and not --force, which the sweep refuses' --force "$out"

set out (fish --no-config -c "$comp complete -C'gwa '")
eq 'gwa offers nothing for NAME, which does not exist yet' '' "$out"
set out (fish --no-config -c "$comp complete -C'gwa newname '")
has 'and branch names for BASE' other "$out"
set out (fish --no-config -c "$comp complete -C'gwa --no-fetch newname '")
has 'even after a flag' other "$out"

set out (fish --no-config -c "$comp complete -C'gwm '")
eq 'gwm offers nothing for NEW either' '' "$out"

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
if have_tty_runner
    with_tty "set -gx PATH $fake \$PATH
        set -gx FAKE_FZF_LINES $seen
        cd $repo4
        _gw_pick 'worktree>' ''"
else
    skip 'the picker preview assertions (no python3 for a pty)'
    printf '' >$seen
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

# ------------------------------------------------------------- fetch scope
group 'fetch scope'

set -l rootf (fixture)
set -l repof $rootf/parent/demo
cd $repof

# A branch that exists only on the remote, which is the case the default is for.
git push -q origin main:theirs
git branch -q -D -r origin/theirs 2>/dev/null
set -l outf (gwa theirs 2>&1 | string collect)
has 'the default asks the remote about NAME' "already has 'theirs'" "$outf"
cd $repof
eq 'and the branch tracks theirs rather than forking' origin/theirs \
    (git -C $rootf/parent/.worktrees/theirs/demo rev-parse --abbrev-ref 'theirs@{upstream}' 2>/dev/null)

# ls-remote matches the tail of a ref path, so a bare name must not be answered
# for by a nested branch that ends with it.
cd $repof
git push -q origin main:feat/login
git branch -q -D -r origin/feat/login 2>/dev/null
set outf (gwa login 2>&1 | string collect)
hasnt 'a nested branch does not answer for a bare name' "already has 'login'" "$outf"
hasnt 'so nothing is fetched that is not there' 'could not fetch' "$outf"

cd $repof
_gw_remote_has_branch origin feat/login
eq 'the probe finds the nested branch' 0 $status
_gw_remote_has_branch origin login
eq 'and not the bare name it ends with' 1 $status
_gw_remote_has_branch origin main
eq 'and still finds an ordinary one' 0 $status

# `git_worktree_fetch yes` is how to decline the round trip.
cd $repof
git push -q origin main:mine
git branch -q -D -r origin/mine 2>/dev/null
begin
    set -lx git_worktree_fetch yes
    set outf (gwa mine 2>&1 | string collect)
end
hasnt 'git_worktree_fetch yes asks the remote nothing about NAME' 'already has' "$outf"

cd $repof
begin
    set -lx git_worktree_fetch no
    set outf (gwa offline/one 2>&1 | string collect)
end
hasnt 'and no stays off the network entirely' fetching "$outf"

# The same answer, recorded where the Zsh plugin and the origin CLI can read
# it too.
cd $repof
git config git-worktree-plugin.fetch no
set outf (gwa keyed/one 2>&1 | string collect)
hasnt 'git-worktree-plugin.fetch no keeps gwa offline' fetching "$outf"

cd $repof
begin
    set -lx git_worktree_fetch always
    set outf (gwa keyed/two 2>&1 | string collect)
end
has 'and git_worktree_fetch outranks the key' fetching "$outf"

cd $repof
set outf (gwr --all 2>&1 | string collect)
hasnt 'the sweep reads the same key' fetching "$outf"

cd $repof
eq 'the policy reads the key when something says' yes (begin
    git config git-worktree-plugin.fetch yes
    _gw_fetch_policy always
end)
git config --unset git-worktree-plugin.fetch
eq 'and falls back when nothing does' always (_gw_fetch_policy always)

cd /
cleanup
echo
echo "  $PASS passed, $FAIL failed"
test $FAIL -eq 0
