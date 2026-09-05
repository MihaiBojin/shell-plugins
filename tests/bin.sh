#!/bin/sh
#
# The scripts in bin/, exercised through stubs on $PATH:
#
#     tests/bin.sh
#
# `battery` keys off pmset's presence rather than the operating system, and
# `macos` asks `uname -s`, so both branches can be driven from either platform
# by putting a stub in front. Nothing here downloads, mounts or installs
# anything: the commands that would are checked for the arguments they refuse.
#
# shellcheck disable=SC1007  # `CDPATH= cd` is the idiom, not a typo'd assignment
# shellcheck disable=SC2015  # `A && pass || fail` is deliberate: pass never fails
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1" >&2; [ -n "${2-}" ] && printf '        %s\n' "$2" >&2; return 0; }
eq()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$2], got [$3]"; }
has()  { case $3 in *"$2"*) ok "$1" ;; *) bad "$1" "[$3] does not contain [$2]" ;; esac; }
hasnt(){ case $3 in *"$2"*) bad "$1" "[$3] should not contain [$2]" ;; *) ok "$1" ;; esac; }
group(){ printf '\n%s\n' "$1"; }

STUB=$(mktemp -d)
trap 'rm -rf "$STUB"' EXIT INT TERM
PATH=$STUB:$PATH
export PATH

# $1 is what the stub pmset prints.
pmset_says() {
    printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "'$1'" > "$STUB/pmset"
    chmod +x "$STUB/pmset"
}

# $1 is what the stub uname prints, whatever it is asked.
uname_says() {
    printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "'$1'" > "$STUB/uname"
    chmod +x "$STUB/uname"
}

group "battery"
pmset_says " -InternalBattery-0 (id=123)	18%; discharging; 1:23 remaining present: true"
out=$("$ROOT/bin/battery")
has "a discharging battery shows the percentage"    "18%"        "$out"
has "a discharging battery shows what pmset called it" "discharging" "$out"
has "a discharging battery shows the time left"     "(1:23 left)" "$out"
hasnt "output that is not a terminal is not coloured" "$(printf '\033')" "$out"

eq "--percent prints the number alone" "18" "$("$ROOT/bin/battery" --percent)"
eq "-p is the same" "18" "$("$ROOT/bin/battery" -p)"

out=$("$ROOT/bin/battery" --plain)
eq "--plain drops the icon" "18% discharging (1:23 left)" "$out"

pmset_says " -InternalBattery-0 (id=123)	90%; charging; 0:30 remaining present: true"
out=$("$ROOT/bin/battery")
has "a charging battery counts down to full, not to empty" "(0:30 to full)" "$out"

pmset_says " -InternalBattery-0 (id=123)	100%; charged; 0:00 remaining present: true"
out=$("$ROOT/bin/battery")
has "a charged battery says so" "100% charged" "$out"

# A healthy battery still prints. The prompt segment used to say nothing above
# the threshold; a command you typed has to answer.
pmset_says " -InternalBattery-0 (id=123)	90%; discharging; 3:00 remaining present: true"
out=$("$ROOT/bin/battery")
has "a healthy battery is printed too" "90%" "$out"

pmset_says "Now drawing from 'AC Power'"
out=$("$ROOT/bin/battery" 2>&1) && status=0 || status=$?
eq "no battery exits 1" "1" "$status"
has "no battery says so" "no battery found" "$out"

out=$("$ROOT/bin/battery" --nonsense 2>&1) && status=0 || status=$?
eq "an unknown option exits 2" "2" "$status"

group "macos"
uname_says Linux
out=$("$ROOT/bin/macos" install-pkg https://example.invalid/x.pkg 2>&1) && status=0 || status=$?
eq "install-pkg refuses to run off macOS" "1" "$status"
has "and names the command that refused" "macos install-pkg only works on macOS" "$out"

out=$("$ROOT/bin/macos" dock clear 2>&1) && status=0 || status=$?
eq "so does dock" "1" "$status"

# Provisioning a Linux box calls these, so the gate is per command rather than
# one refusal at the top.
LINUXWORK=$(mktemp -d)
printf 'target\n' > "$LINUXWORK/target"
out=$("$ROOT/bin/macos" link-if-different "$LINUXWORK/target" "$LINUXWORK/link" 2>&1) && status=0 || status=$?
eq "link-if-different runs off macOS" "0" "$status"
eq "backup-if-exists too" "0" \
   "$("$ROOT/bin/macos" backup-if-exists "$LINUXWORK/absent" >/dev/null 2>&1; echo $?)"
rm -rf "$LINUXWORK"

out=$("$ROOT/bin/macos" help 2>&1) && status=0 || status=$?
eq "help works anywhere" "0" "$status"
has "help lists the commands" "install-dmg-pkg" "$out"

uname_says Darwin
out=$("$ROOT/bin/macos" 2>&1) && status=0 || status=$?
eq "no command at all exits 2" "2" "$status"
has "and prints the usage" "usage: macos" "$out"

out=$("$ROOT/bin/macos" frobnicate 2>&1) && status=0 || status=$?
eq "an unknown command exits 2" "2" "$status"

out=$("$ROOT/bin/macos" install-pkg 2>&1) && status=0 || status=$?
eq "install-pkg without a URL exits 2" "2" "$status"
has "and prints that command's usage" "usage: macos install-pkg URL" "$out"

out=$("$ROOT/bin/macos" install-dmg https://example.invalid/x.dmg 2>&1) && status=0 || status=$?
eq "install-dmg with one of two arguments exits 2" "2" "$status"
has "and prints that command's usage" "usage: macos install-dmg URL APP" "$out"

out=$("$ROOT/bin/macos" install-dmg-pkg https://example.invalid/x.dmg 2>&1) && status=0 || status=$?
eq "install-dmg-pkg with one of two arguments exits 2" "2" "$status"
has "and prints that command's usage" "usage: macos install-dmg-pkg URL PKG" "$out"

# The signature these two used to have. Refused rather than read as URL + PKG.
out=$("$ROOT/bin/macos" install-dmg https://example.invalid/x.dmg Volume App 2>&1) && status=0 || status=$?
eq "the old three-argument install-dmg call is refused" "2" "$status"
has "and says which argument went away" "the VOLUME argument is gone" "$out"

out=$("$ROOT/bin/macos" dock 2>&1) && status=0 || status=$?
eq "dock without a subcommand exits 2" "2" "$status"

WORK=$(mktemp -d)
out=$("$ROOT/bin/macos" backup-if-exists "$WORK/absent" 2>&1) && status=0 || status=$?
eq "backup-if-exists says nothing about a path that is not there" "" "$out"
eq "and succeeds" "0" "$status"

printf 'old\n' > "$WORK/file"
"$ROOT/bin/macos" backup-if-exists "$WORK/file" >/dev/null
[ -e "$WORK/file" ] && bad "backup-if-exists left the original in place" \
    || ok "backup-if-exists moved the original aside"
eq "and named the copy after the moment" "1" \
   "$(find "$WORK" -name 'file.backup.*' | wc -l | tr -d ' ')"

printf 'target\n' > "$WORK/target"
"$ROOT/bin/macos" link-if-different "$WORK/target" "$WORK/link" >/dev/null
eq "link-if-different points the link where it was told" "$WORK/target" \
   "$(readlink "$WORK/link")"
out=$("$ROOT/bin/macos" link-if-different "$WORK/target" "$WORK/link")
has "and does nothing the second time" "Nothing to do." "$out"

printf 'in the way\n' > "$WORK/occupied"
"$ROOT/bin/macos" link-if-different "$WORK/target" "$WORK/occupied" >/dev/null
eq "a file in the way is backed up, not overwritten" "1" \
   "$(find "$WORK" -name 'occupied.backup.*' | wc -l | tr -d ' ')"
eq "and the link is made" "$WORK/target" "$(readlink "$WORK/occupied")"
rm -rf "$WORK"

printf '\n'
printf 'bin: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
