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
begin
    set -lx PATH $fake $PATH
    set -lx FAKE_FZF_LINES $seen2
    _git_alias_branch_pick 'branch>' '' >/dev/null
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
    set picked (_git_alias_branch_pick 'branch>' '' '' </dev/null 2>/dev/null)
    set rc $status
end
eq 'closed stdin makes the picker fail' 1 $rc
eq 'and it names no branch' 0 (count $picked)
popd >/dev/null

cleanup
echo
echo "  $PASS passed, $FAIL failed"
test $FAIL -eq 0
