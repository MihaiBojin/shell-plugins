#!/usr/bin/env fish
#
# Behavioural tests for the Fish git-alias commands. The abbreviations need an
# interactive shell to exist at all, and the two helpers need real repositories
# to say anything useful, so this runs as:
#
#     fish --no-config -i tests/fish/git-alias.fish
#
# git's own configuration is isolated: a global init.defaultBranch would
# otherwise decide whether the default-branch tests pass.

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

function has -a desc needle haystack
    string match --quiet "*$needle*" -- "$haystack"; and ok $desc
    or bad $desc "[$haystack] does not contain [$needle]"
end

function sandbox
    set -l dir (path resolve (mktemp -d))
    set -ga SANDBOXES $dir
    echo $dir
end

function cleanup
    for s in $SANDBOXES
        rm -rf $s
    end
end

# ------------------------------------------------------------ abbreviations
echo
echo 'abbreviations'

if not status is-interactive
    echo "  FAIL  this file has to run under `fish -i`; abbreviations do not exist otherwise" >&2
    exit 1
end

source $ROOT/conf.d/git-alias.fish

eq 'every abbreviation is declared' 22 (abbr --list | count)
eq 'ga adds' 'git add' (abbr --show | string match -r "abbr -a -- ga '(.*)'" | tail -1)
has 'gst is git status' "abbr -a -- gst 'git status'" (abbr --show | string join ' ')
has 'gca! amends' "gca! 'git commit --verbose --all --amend'" (abbr --show | string join ' ')
has 'gcm asks the repository for its default branch' "gcm 'git checkout (_git_alias_main_branch)'" (abbr --show | string join ' ')
has 'gpsup asks for the current branch' '_git_alias_current_branch' (abbr --show | string join ' ')
has 'gh-login carries the scopes a new machine needs' 'admin:public_key' (abbr --show | string join ' ')

for name in gwip gunwip gunwipall
    if contains -- $name (abbr --list)
        bad "$name is a function, not an abbreviation"
    else
        ok "$name is left to the function that already exists"
    end
end

# ------------------------------------------------------------------ helpers
echo
echo 'helpers'

set -l repo (sandbox)/repo
git init -q --initial-branch=main $repo
git -C $repo commit -q --allow-empty -m base

pushd $repo >/dev/null
eq 'the current branch is the one checked out' main (_git_alias_current_branch)

git checkout -q -b feature/x
eq 'a slashed branch comes back whole' feature/x (_git_alias_current_branch)

git checkout -q --detach
eq 'a detached HEAD has no branch' '' (_git_alias_current_branch)
git checkout -q main

eq 'the default branch falls back to a local head' main (_git_alias_main_branch)

git checkout -q -b trunk
git branch -q -m main old-main
eq 'trunk is recognised when main is gone' trunk (_git_alias_main_branch)
git branch -q -m old-main main
git checkout -q main
git branch -q -D trunk

# What the remote advertised beats any local guess.
set -l origin (sandbox)/origin.git
git init -q --bare --initial-branch=master $origin
git -C $repo remote add origin $origin
git -C $repo push -q origin main:master
git -C $repo remote set-head origin --auto >/dev/null 2>&1
eq 'the remote HEAD wins over a local main' master (_git_alias_main_branch)
popd >/dev/null

set -l bare (sandbox)
pushd $bare >/dev/null
if _git_alias_main_branch >/dev/null 2>&1
    bad 'outside a repository it fails'
else
    ok 'outside a repository it fails'
end
popd >/dev/null

# ------------------------------------------------------- branch bookkeeping
echo
echo 'branch state'

# One repository, one branch per way a branch can end.
set -l bs (sandbox)/branches
git init -q --initial-branch=main $bs
pushd $bs >/dev/null
git commit -q --allow-empty -m base

git checkout -q -b merged
echo a >a; git add a; git commit -q -m a
git checkout -q main
git merge -q --no-ff merged -m 'merge merged'

git checkout -q -b squashed main
echo b >b; git add b; git commit -q -m b
git checkout -q main
git merge -q --squash squashed >/dev/null
git commit -q -m 'squash b'

git checkout -q -b alone main
echo c >c; git add c; git commit -q -m c
git checkout -q main
git branch twin alone

git checkout -q -b nowhere main
echo d >d; git add d; git commit -q -m d
git checkout -q main

has 'a merged branch says so' 'merged into main' (_git_alias_branch_state merged)
has 'a squashed branch is recognised by content' 'squash-merged into main' (_git_alias_branch_state squashed)
has 'a branch another ref holds says which' 'same commit as twin' (_git_alias_branch_state alone)
has 'a branch that is nowhere else says so' 'not in main' (_git_alias_branch_state nowhere)

_git_alias_branch_state merged >/dev/null
eq 'merged exits 0' 0 $status
_git_alias_branch_state squashed >/dev/null
eq 'squash-merged exits 0' 0 $status
_git_alias_branch_state alone >/dev/null
eq 'held by another ref exits 0' 0 $status
_git_alias_branch_state nowhere >/dev/null
eq 'unreferenced exits 1' 1 $status

# gbd refuses the two branches it must never take.
gbd --force main 2>/dev/null
eq 'gbd will not delete the default branch' 1 $status
has 'main survives' ' main' (git branch | string join ' ')

git checkout -q nowhere
gbd --force nowhere 2>/dev/null
eq 'gbd will not delete the branch you are on' 1 $status
git checkout -q main

gbd --force squashed >/dev/null
eq 'gbd deletes a squash-merged branch' 0 $status
eq 'and it is gone' '' (git branch --list squashed | string trim)
popd >/dev/null

# --------------------------------------------------------- picker preview
echo
echo 'picker preview'

# The preview pane runs a git command against one field of the line, and the
# other fields are shaped for a human: a branch truncated to 34 columns, a
# relative date, a subject. Point the preview at one of those and it fails on
# every keystroke — which is invisible, because a preview that errors just
# looks like a preview with nothing in it.
#
# So stand in for fzf and look at what it was handed. $fake goes on the front
# of PATH, prints the lines it was given, and picks the first.
set -l fake (sandbox)
echo '#!/bin/sh
cat > "$FAKE_FZF_LINES"
head -1 "$FAKE_FZF_LINES"' >$fake/fzf
chmod +x $fake/fzf

pushd $bs >/dev/null
set -l seen (sandbox)/lines
begin
    set -lx PATH $fake $PATH
    set -lx FAKE_FZF_LINES $seen
    _git_alias_branch_pick 'branch>' '' >/dev/null
end

set -l last_fields
for line in (cat $seen)
    set -a last_fields (string split \t -- $line)[-1]
end

eq 'every line carries a last field' (count (cat $seen)) (count $last_fields)

set -l bad 0
for b in $last_fields
    git rev-parse --verify --quiet refs/heads/$b >/dev/null; or set bad (math $bad + 1)
end
eq 'the preview field is a real branch on every line' 0 $bad

# And the preview must read that field rather than a fixed index, so adding a
# column cannot silently point it at the wrong one.
set -l src (cat $ROOT/functions/_git_alias_branch_pick.fish)
set -l previews (string match -r -- "--preview='[^']*'" (string join ' ' $src))
has 'the preview reads the last field' '{-1}' "$previews"
popd >/dev/null

# ---------------------------------------------------- what the picker marks
echo
echo 'picker marker'

# %(HEAD) is '*' on the checked-out branch and a single space on every other
# one, so the marker has to compare against the '*'. Asking whether the field
# is empty marks the whole list — on the picker branches get deleted from.
pushd $bs >/dev/null
set -l seen2 (sandbox)/lines2
if have_tty_runner
    with_tty "set -gx PATH $fake \$PATH
        set -gx FAKE_FZF_LINES $seen2
        cd $bs
        _git_alias_branch_pick 'branch>' ''"
else
    skip 'the picker marker assertions (no python3 for a pty)'
    printf '' >$seen2
end

set -l marked 0
set -l total 0
for line in (cat $seen2)
    set total (math $total + 1)
    string match --quiet -- '\**' $line; and set marked (math $marked + 1)
end
eq 'the picker offered more than one branch' 1 (test $total -gt 1; and echo 1; or echo 0)
eq 'exactly one of them is marked as checked out' 1 $marked

set -l current (git rev-parse --abbrev-ref HEAD)
set -l marked_branch
for line in (cat $seen2)
    string match --quiet -- '\**' $line; and set marked_branch (string split \t -- $line)[-1]
end
eq 'and it is the branch actually checked out' $current $marked_branch

# ------------------------------------------------------- the picker at EOF
echo
echo 'picker at EOF'

# Without fzf the picker reads a number. A failed read is not an empty answer:
# falling through to the [1] default hands back the newest branch nobody chose,
# and gbd --force deletes it.
set -l picked
set -l rc 0
begin
    set -lx PATH /usr/bin /bin /usr/sbin /sbin
    _git_alias_branch_pick 'branch>' '' '' </dev/null 2>/dev/null
    set rc $status
    set picked $_git_alias_reply
end
eq 'closed stdin makes the picker fail' 1 $rc
eq 'and it names no branch' 0 (count $picked)

# The callers reach the picker without a command substitution, so a redirect on
# them reaches its `read`. Through one, fish hands `read` the terminal instead
# and gbd waits on a keyboard nobody is at.
begin
    set -lx PATH /usr/bin /bin /usr/sbin /sbin
    gbd </dev/null 2>/dev/null
    eq 'gbd gives up on closed stdin rather than waiting' 1 $status
    gb </dev/null 2>/dev/null
    eq 'and so does gb' 1 $status
end

# The last field is the raw branch, hidden from the fzf view by --with-nth and
# read by the preview as {-1}; printed in the numbered list it is the first
# column over again.
begin
    set -lx PATH /usr/bin /bin /usr/sbin /sbin
    _git_alias_branch_pick 'branch>' '' '' </dev/null 2>$bs/numbered
end
# The hidden field is tab-separated from the rest, so the fix is visible as
# the absence of a tab: what is printed is now the columns a person reads.
set -l tab (printf '\t')
set -l tabs 0
for line in (cat $bs/numbered)
    string match --quiet -- "*$tab*" $line; and set tabs (math $tabs + 1)
end
eq 'the numbered list drops the raw branch it used to repeat' 0 $tabs
popd >/dev/null

# --------------------------------------------------------------------- gnb
echo
echo 'gnb'

# A server, a clone of it, and a commit pushed after the clone. Branching from
# the local main would miss that commit; branching from origin/main does not,
# which is the whole point of the command.
set -l server (sandbox)/server.git
git init -q --bare --initial-branch=main $server
set -l seed (sandbox)/seed
git init -q --initial-branch=main $seed
git -C $seed commit -q --allow-empty -m base
git -C $seed remote add origin $server
git -C $seed push -q origin main

set -l clone (sandbox)/clone
git clone -q $server $clone 2>/dev/null

git -C $seed commit -q --allow-empty -m ahead
git -C $seed push -q origin main
set -l tip (git -C $seed rev-parse HEAD)

pushd $clone >/dev/null
set -l stale (git rev-parse main)

gnb >/dev/null 2>&1
eq 'gnb with no name exits 2' 2 $status
gnb one two >/dev/null 2>&1
eq 'gnb with two names exits 2' 2 $status
gnb 'not a branch' >/dev/null 2>&1
eq 'gnb refuses an invalid branch name' 2 $status
gnb main >/dev/null 2>&1
eq 'gnb refuses a name that is already a branch' 1 $status
eq 'and leaves you where you were' main (_git_alias_current_branch)

gnb feat/oauth >/dev/null 2>&1
eq 'gnb exits 0' 0 $status
eq 'and checks the new branch out' feat/oauth (_git_alias_current_branch)
eq 'starting at what the server has' $tip (git rev-parse HEAD)
eq 'not at the local copy of the default branch' $stale (git rev-parse main)
eq 'and tracking nothing, so git pull cannot reach for main' '' (git config --get branch.feat/oauth.merge)

set -l out (gnb feat/oauth 2>&1 >/dev/null | string collect)
has 'a name already taken says what checks it out' 'gb feat/oauth' "$out"
popd >/dev/null

set -l elsewhere (sandbox)
pushd $elsewhere >/dev/null
gnb anything >/dev/null 2>&1
eq 'gnb outside a repository exits 1' 1 $status
popd >/dev/null

# ------------------------------------------------------------ remote choice
echo
echo 'which remote'

set -l multi (sandbox)/multi
git init -q --initial-branch=main $multi
git -C $multi commit -q --allow-empty -m base
set -l up (sandbox)/up.git
set -l fork (sandbox)/fork.git
git init -q --bare --initial-branch=develop $up
git init -q --bare --initial-branch=main $fork

pushd $multi >/dev/null
git remote add upstream $up
git push -q upstream main:develop
eq 'one remote needs no configuration at all' upstream (_git_alias_remote)

git remote add fork $fork
git push -q fork main
git fetch -q --all
git remote set-head upstream --auto >/dev/null 2>&1
git remote set-head fork --auto >/dev/null 2>&1

# Neither is called origin, and nothing has been configured yet.
git config --unset branch.main.remote 2>/dev/null
eq 'with two remotes and nothing said, the first is taken' (git remote | head -1) (_git_alias_remote)

git config checkout.defaultRemote upstream
eq 'checkout.defaultRemote decides' upstream (_git_alias_remote)
git config --unset checkout.defaultRemote

git config branch.main.remote fork
eq 'branch.<current>.remote decides' fork (_git_alias_remote)

# remote.pushDefault is the push target and must not move the base.
git config remote.pushDefault upstream
eq 'remote.pushDefault does not decide the base' fork (_git_alias_remote)
eq 'but it does decide the push target' upstream (_git_alias_push_remote)
# git's own precedence: branch.<name>.pushRemote wins over remote.pushDefault.
git config branch.main.pushRemote fork
eq 'branch.<current>.pushRemote overrides it, as git-config says' fork (_git_alias_push_remote)
git config --unset branch.main.pushRemote
git config --unset remote.pushDefault
eq 'unset, the push target is the base remote' fork (_git_alias_push_remote)

eq 'the default branch comes from that remote' main (_git_alias_main_branch)
eq 'and each remote advertises its own' develop (_git_alias_main_branch upstream)

gnb feat/from-fork >/dev/null 2>&1
eq 'gnb branches off the resolved remote' (git rev-parse refs/remotes/fork/main) (git rev-parse HEAD)
git checkout -q main

git config branch.main.remote upstream
gnb feat/from-upstream >/dev/null 2>&1
eq 'and follows the configuration when it changes' (git rev-parse refs/remotes/upstream/develop) (git rev-parse HEAD)
popd >/dev/null

cleanup
echo
echo "  $PASS passed, $FAIL failed"
test $FAIL -eq 0
