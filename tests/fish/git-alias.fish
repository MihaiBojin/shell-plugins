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

cleanup
echo
echo "  $PASS passed, $FAIL failed"
test $FAIL -eq 0
