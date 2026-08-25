#!/bin/sh
#
# Everything, in one command:
#
#     tests/run.sh
#
# Static syntax checks, then isolated smoke tests for each shell and for the
# scripts in bin/, then the repository hygiene checks. Written in POSIX sh so it
# runs from any shell, and it skips (loudly) whichever of zsh/fish is not
# installed rather than failing — a machine only ever needs one of them.
#
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

RC=0
step()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
fail()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1" >&2; RC=1; }
pass()  { printf '  ok    %s\n' "$1"; }
skip()  { printf '  \033[33mskip\033[0m  %s\n' "$1"; }

# ---------------------------------------------------------------- zsh syntax
step "zsh -n"
if command -v zsh >/dev/null 2>&1; then
    for f in shell-plugins.plugin.zsh \
             zsh/plugins/*/*.plugin.zsh \
             zsh/plugins/*/functions/* \
             zsh/plugins/*/completions/* \
             tests/zsh/*.zsh; do
        [ -f "$f" ] || continue
        # A syntax check must be silent as well as successful: zsh reports some
        # runtime problems from `-n` without failing.
        out=$(zsh -n "$f" 2>&1) || { fail "$f does not parse"; continue; }
        [ -z "$out" ] && pass "$f" || fail "$f parses but complains: $out"
    done
else
    skip "zsh is not installed"
fi

# --------------------------------------------------------------- fish syntax
step "fish -n"
if command -v fish >/dev/null 2>&1; then
    for f in functions/*.fish conf.d/*.fish completions/*.fish tests/fish/*.fish; do
        [ -f "$f" ] || continue
        out=$(fish -n "$f" 2>&1) || { fail "$f does not parse"; continue; }
        [ -z "$out" ] && pass "$f" || fail "$f parses but complains: $out"
    done
else
    skip "fish is not installed"
fi

# -------------------------------------------------------------- bash syntax
step "bash -n"
for f in bin/*; do
    [ -f "$f" ] || continue
    out=$(bash -n "$f" 2>&1) || { fail "$f does not parse"; continue; }
    [ -z "$out" ] && pass "$f" || fail "$f parses but complains: $out"
done

# The scripts in bin/ ship; the test harness does not, and predates the check.
step "shellcheck bin/"
if command -v shellcheck >/dev/null 2>&1; then
    for f in bin/*; do
        [ -f "$f" ] || continue
        out=$(shellcheck "$f" 2>&1) && pass "$f" \
            || { printf '%s\n' "$out" >&2; fail "$f has shellcheck findings"; }
    done
else
    skip "shellcheck is not installed"
fi

# ----------------------------------------------------------------- zsh smoke
step "zsh smoke tests (zsh -f)"
if command -v zsh >/dev/null 2>&1; then
    zsh -f tests/zsh/smoke.zsh || RC=1
else
    skip "zsh is not installed"
fi

step "git-worktree behaviour, zsh (real repositories)"
if command -v zsh >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    zsh -f tests/zsh/git-worktree.zsh || RC=1
else
    skip "zsh or git is not installed"
fi

step "git-worktree behaviour, fish (real repositories)"
if command -v fish >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    fish --no-config tests/fish/git-worktree.fish || RC=1
else
    skip "fish or git is not installed"
fi

step "git-alias behaviour, zsh (real repositories)"
if command -v zsh >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    zsh -f tests/zsh/git-alias.zsh || RC=1
else
    skip "zsh or git is not installed"
fi

step "git-alias behaviour, fish (abbreviations need an interactive shell)"
if command -v fish >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    fish --no-config -i tests/fish/git-alias.fish || RC=1
else
    skip "fish or git is not installed"
fi

# ---------------------------------------------------------------- fish smoke
step "fish smoke tests (fish --no-config)"
if command -v fish >/dev/null 2>&1; then
    fish --no-config tests/fish/smoke.fish || RC=1
else
    skip "fish is not installed"
fi

# ----------------------------------------------------------------- bin smoke
step "bin/ behaviour (stubbed pmset and uname)"
sh tests/bin.sh || RC=1

# ----------------------------------------------------------- repository checks
step "repository checks"

# Every file that ships. The list is enumerated rather than "everything under
# the root", so a new top-level file has to be added here deliberately before
# the checks below start covering it.
SHIPPED=$(find shell-plugins.plugin.zsh zsh bin functions conf.d completions \
               docs tests README.md LICENSE -type f 2>/dev/null | sort)

# `.git` is a directory in a clone and a *file* in a worktree, so ask git
# rather than looking for a directory — otherwise every check below silently
# skips whenever the work happens in a worktree.
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    if git diff --check >/dev/null 2>&1; then
        pass "git diff --check"
    else
        git diff --check >&2
        fail "git diff --check found whitespace errors"
    fi
else
    skip "not a git repository"
fi

found=$(printf '%s\n' "$SHIPPED" | xargs grep -n '[	 ]$' 2>/dev/null || true)
[ -z "$found" ] && pass "no trailing whitespace" || { printf '%s\n' "$found" >&2; fail "trailing whitespace"; }

# Absolute paths that would only exist on one machine. `~` and $HOME are fine;
# a hard-coded /Users/... or /opt/homebrew is not.
found=$(printf '%s\n' "$SHIPPED" \
    | xargs grep -nE '(/Users/|/home/[a-z]|/opt/homebrew|/usr/local/opt/|/nix/store/)' 2>/dev/null \
    | grep -v '^tests/' || true)
[ -z "$found" ] && pass "no machine-specific absolute paths" \
    || { printf '%s\n' "$found" >&2; fail "machine-specific absolute paths"; }

# Anything that smells like a credential or a private/work-specific value.
found=$(printf '%s\n' "$SHIPPED" | grep -v '^tests/' \
    | xargs grep -niE '(api[_-]?key|secret|passwd|password|token|BEGIN [A-Z ]*PRIVATE KEY|teleport|databricks|neon\.tech)' 2>/dev/null || true)
[ -z "$found" ] && pass "no secrets or work-specific values" \
    || { printf '%s\n' "$found" >&2; fail "possible secret or private value"; }

# An fzf --preview runs against one field of the line, and the other fields are
# shaped for a human: a path with $HOME shortened to ~, a name truncated to fit
# a column. Point a preview at a numbered field and it breaks the moment a
# column is added or reordered, silently — a preview that errors looks exactly
# like a preview with nothing to show. So the machine-readable value goes last
# on the line and every preview asks for {-1}.
found=$(printf '%s\n' "$SHIPPED" | grep -v '^tests/' \
    | xargs grep -n -- "--preview=" 2>/dev/null | grep -E '\{[0-9]+\}' || true)
[ -z "$found" ] && pass "every fzf preview reads {-1}, not a numbered field" \
    || { printf '%s\n' "$found" >&2; fail "an fzf preview reads a numbered field"; }

# Nothing in the package may assume a platform without saying so.
found=$(printf '%s\n' "$SHIPPED" | grep -v '^docs/\|^tests/\|README.md$' \
    | xargs grep -nE '\b(brew|apt-get|yum|dnf|pacman|nix-env)\b' 2>/dev/null || true)
[ -z "$found" ] && pass "no package-manager calls" \
    || { printf '%s\n' "$found" >&2; fail "package-manager call in shipped code"; }

# Exactly one entry point per logical plugin, and one aggregate at the root.
for d in zsh/plugins/*/; do
    n=$(basename "$d")
    c=$(find "$d" -maxdepth 1 -name '*.plugin.zsh' | wc -l | tr -d ' ')
    [ "$c" = "1" ] && [ -f "$d$n.plugin.zsh" ] \
        && pass "$n has exactly one entry point" \
        || fail "$n should have exactly one $n.plugin.zsh (found $c)"
done
# A script in bin/ that is not executable is on $PATH and unusable, and the
# only sign of it is "command not found" from a file you can see is there.
found=$(find bin -type f ! -perm -u+x 2>/dev/null || true)
[ -z "$found" ] && pass "everything in bin/ is executable" \
    || { printf '%s\n' "$found" >&2; fail "not executable"; }

c=$(find . -maxdepth 1 -name '*.plugin.zsh' | wc -l | tr -d ' ')
[ "$c" = "1" ] && pass "exactly one aggregate entry point at the root" \
    || fail "expected one *.plugin.zsh at the root, found $c"

printf '\n'
if [ "$RC" = "0" ]; then
    printf '\033[32mall checks passed\033[0m\n'
else
    printf '\033[31msome checks failed\033[0m\n'
fi
exit "$RC"
