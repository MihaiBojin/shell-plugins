#!/usr/bin/env fish
#
# Fish smoke tests. Run with --no-config so nothing here can accidentally
# depend on a personal config.fish:
#
#     fish --no-config tests/fish/smoke.fish
#
# The discovery tests go further and build a throwaway Fisher-shaped install
# under $XDG_CONFIG_HOME, so "the package works" means "the files land where
# Fisher puts them and Fish autoloads them from there".
#

# A UTF-8 locale, or the prompt's chevron comes back as two bytes of mojibake
# and the assertions below compare mangled output. Everything else here is
# deliberately at the mercy of the caller's environment — a package should
# behave the way it does for a person — but text encoding is not something a
# test should be guessing at.
for candidate in C.UTF-8 en_US.UTF-8
    if locale -a 2>/dev/null | string match --quiet --entire -- $candidate
        set -gx LC_ALL $candidate
        break
    end
end

set -g ROOT (path resolve (status dirname)/../..)
set -g FISH (status fish-path)
set -g PASS 0
set -g FAIL 0

function ok
    set -g PASS (math $PASS + 1)
    echo "  ok    $argv[1]"
end

function bad
    set -g FAIL (math $FAIL + 1)
    echo "  FAIL  $argv[1]" >&2
    set -q argv[2]; and echo "        $argv[2]" >&2
    # Succeed, like ok does. The inverted checks below are written
    # `cond; and bad ...` / `or ok ...`, and a failing bad would let the
    # trailing `or` fire too — printing FAIL and then a contradictory ok, and
    # counting the case as passed.
    return 0
end

function eq -a desc expected actual
    test "$expected" = "$actual"; and ok $desc; or bad $desc "expected [$expected], got [$actual]"
end

function has -a desc needle haystack
    string match --quiet "*$needle*" -- "$haystack"; and ok $desc
    or bad $desc "[$haystack] does not contain [$needle]"
end

function group
    echo
    echo $argv[1]
end

#
# 1. Package layout — what Fisher will actually copy.
#
group "Fisher package layout"
for d in functions conf.d completions
    test -d $ROOT/$d; and ok "$d/ exists at the repository root"
    or bad "$d/ is missing from the repository root"
end
test -d $ROOT/fish; and bad "there is a fish/ directory — the package must live at the root"
or ok "there is no fish/ directory to confuse Fisher"

# conf.d runs on every interactive start, so what lives there is deliberate and
# enumerated: the abbreviations, which cannot exist any other way, and the
# transient right prompt, which has to register a key binding before the first
# line is typed. A third file has to be added here before it is allowed.
set -l confd (path basename $ROOT/conf.d/*.fish)
eq "conf.d/ holds only what must run at startup" "battery-prompt.fish git-alias.fish" (string join ' ' $confd)

set -l offenders (string match --regex --invert '^\s*(#|$|if status is-interactive|end|abbr --add )' <$ROOT/conf.d/git-alias.fish)
eq "conf.d/git-alias.fish only declares abbreviations" "" (string join ' ' $offenders)

# One public function per file, named after the file.
for file in $ROOT/functions/*.fish
    set -l name (path basename $file | string replace -r '\.fish$' '')
    if string match --quiet --regex "(?m)^function\s+$name(\s|\$)" -- (cat $file | string collect)
        ok "functions/$name.fish defines $name"
    else
        bad "functions/$name.fish does not define a function called $name"
    end
end

#
# 2. Discovery through a throwaway Fisher-shaped install.
#
group "autoloading from a Fisher-shaped install"
set -l sandbox (mktemp -d)
mkdir -p $sandbox/config/fish $sandbox/data $sandbox/home
cp -R $ROOT/functions $ROOT/conf.d $ROOT/completions $sandbox/config/fish/
test -f $sandbox/config/fish/config.fish; and bad "the sandbox has a config.fish"
or ok "the sandbox has no config.fish at all"

# Deliberately *not* --no-config: that empties $fish_function_path, and
# autoloading from the installed layout is exactly what is under test. The
# sandbox has no config.fish, but the machine's own fish prefix may still ship
# vendor conf.d snippets, so these captures read stdout only and the stderr
# assertions below match on a substring.
set -l isolated env XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data HOME=$sandbox/home $FISH

set -l out ($isolated --command '
    for f in fish_prompt fish_right_prompt dns_records gwip gunwip gunwipall et _shell_terminal_reset _shell_battery_prompt
        functions --query $f; or echo "not discoverable: $f"
    end' 2>/dev/null | string collect)
eq "every packaged function is discoverable without sourcing anything" "" "$out"

set out ($isolated --command 'functions fish_prompt' 2>/dev/null | string collect)
has "the installed fish_prompt is ours, not Fish's default" "Pure-like" "$out"

#
# 3. The prompt.
#
group "prompt"
set out ($isolated --command 'cd $HOME; true; fish_prompt' 2>/dev/null | cat -v | string collect)
has "success prompt is magenta" '^[[35m' "$out"
has "success prompt shows the directory in blue" '^[[34m~' "$out"

# The chevron is compared without `cat -v`. What that renders a multi-byte
# character as depends on the locale — in a UTF-8 one macOS passes ❯ through
# and escapes only the byte in the middle that is not printable on its own,
# so a byte-level expectation is wrong on exactly the machines it matters on.
set -l raw ($isolated --command 'cd $HOME; true; fish_prompt' 2>/dev/null | string collect)
has "success prompt ends in a chevron" '❯' "$raw"

set out ($isolated --command 'cd $HOME; false; fish_prompt' 2>/dev/null | cat -v | string collect)
has "failure prompt is red" '^[[31m' "$out"

set out ($isolated --command 'cd /; true; fish_prompt' 2>/dev/null | cat -v | string collect)
has "the prompt renders at the filesystem root" '^[[34m/' "$out"

# Two lines of prompt plus the leading blank separator line.
set out ($isolated --command 'cd $HOME; true; fish_prompt' 2>/dev/null | string collect --no-trim-newlines | string split \n)
eq "the prompt starts with a blank line" "" "$out[1]"
eq "the prompt is three lines: blank, directory, chevron" "3" (count $out)

#
# 4. Behaviour of the packaged functions.
#
group "command behaviour"
$isolated --command 'dns_records' >/dev/null 2>&1
eq "dns_records without an argument exits 2" "2" "$status"

set -l nopath (mktemp -d)
env XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data HOME=$sandbox/home PATH=$nopath \
    $FISH --command 'dns_records example.com' >/dev/null 2>&1
eq "dns_records without dig exits 127" "127" "$status"
rm -rf $nopath

set -l fakebin (mktemp -d)
printf '#!/bin/sh\nexit 42\n' > $fakebin/et
chmod +x $fakebin/et
env XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data HOME=$sandbox/home PATH=$fakebin:$PATH \
    $FISH --command 'et --whatever' >/dev/null 2>&1
eq "et forwards the exit status of the real et" "42" "$status"

set out (env XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data HOME=$sandbox/home PATH=$fakebin:$PATH \
    $FISH --command 'et --whatever' 2>/dev/null | cat -v | string collect)
eq "et resets the terminal before and after" \
   '^[[?1049l^[[?1047l^[[?47l^[[?1l^[[?1000l^[[?1002l^[[?1003l^[[?1006l^[[?1007l^[[?1049l^[[?1047l^[[?47l^[[?1l^[[?1000l^[[?1002l^[[?1003l^[[?1006l^[[?1007l' \
   "$out"
rm -rf $fakebin

set -l norepo (mktemp -d)
$isolated --command "cd $norepo; gunwipall" >/dev/null 2>&1
eq "gunwipall outside a repository exits 1" "1" "$status"
set out ($isolated --command "cd $norepo; gunwipall" 2>&1 >/dev/null | string collect)
has "gunwipall says why" "not inside a git repository" "$out"
rm -rf $norepo

#
# 5. The battery segment, driven by a stub pmset on $PATH — the same trick the
#    et test uses, so it runs the pmset branch on any OS.
#
group "battery segment"
set -l batbin (mktemp -d)
# $PATH is a list; join it into one string, or `env PATH=$batbin:$PATH` fans
# out into one assignment per element and env keeps only the last.
set -l batpath (string join : $batbin $PATH)
set -l batenv env XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data HOME=$sandbox/home PATH=$batpath $FISH

# Off by default: defining fish_right_prompt must not read a battery. The stub
# leaves a marker if it is ever run, and prints a low reading so a wrong wiring
# would show rather than hide.
printf '#!/bin/sh\ntouch %s/ran\necho " 18%%; discharging; 1:23 remaining"\n' $batbin >$batbin/pmset
chmod +x $batbin/pmset

set out ($batenv --command 'fish_right_prompt' 2>/dev/null | string collect)
eq "fish_right_prompt is empty until opted in" "" "$out"
test -e $batbin/ran; and bad "fish_right_prompt read the battery while switched off"
or ok "fish_right_prompt never forked pmset while switched off"

# Opted in and low: percentage and time both show.
set out ($batenv --command 'set -g shell_battery_prompt_show yes; fish_right_prompt' 2>/dev/null | string collect)
has "an enabled low battery shows the percentage" "18%" "$out"
has "an enabled low battery shows the time remaining" "1:23h left" "$out"

# The renderer stands alone — no opt-in — which is the manual-placement path.
set out ($batenv --command '_shell_battery_prompt' 2>/dev/null | string collect)
has "_shell_battery_prompt renders when called directly" "18%" "$out"

# show_remaining off drops the parenthetical, keeps the percentage.
set out ($batenv --command 'set -g shell_battery_prompt_show_remaining no; _shell_battery_prompt' 2>/dev/null | string collect)
has "show_remaining off keeps the percentage" "18%" "$out"
string match --quiet "*left*" -- "$out"; and bad "show_remaining off still printed the time"
or ok "show_remaining off drops the time remaining"

# A healthy discharging battery says nothing at all.
printf '#!/bin/sh\necho " 90%%; discharging; 3:00 remaining"\n' >$batbin/pmset
set out ($batenv --command '_shell_battery_prompt' 2>/dev/null | string collect)
eq "a healthy battery renders nothing" "" "$out"

# Charging is always shown, even above the high threshold.
printf '#!/bin/sh\necho " 90%%; charging; 0:30 remaining"\n' >$batbin/pmset
set out ($batenv --command '_shell_battery_prompt' 2>/dev/null | string collect)
has "a charging battery is shown above the threshold" "90%" "$out"

rm -rf $batbin

rm -rf $sandbox

echo
echo "fish: $PASS passed, $FAIL failed"
test $FAIL -eq 0
