#!/usr/bin/env zsh
#
# Zsh smoke tests. Run with `zsh -f` so nothing here can accidentally depend on
# a personal .zshrc:
#
#     zsh -f tests/zsh/smoke.zsh
#
# Every isolation test spawns its own `zsh -f`, so a plugin that leaks state
# cannot hide behind one that loaded before it.
#

emulate -L zsh
setopt no_unset warn_create_global

typeset -g ROOT=${${(%):-%x}:A:h:h:h}
typeset -g PLUGINS=$ROOT/zsh/plugins
typeset -g AGG=$ROOT/shell-plugins.plugin.zsh
typeset -g PASS=0 FAIL=0
typeset -g ZSH=${commands[zsh]:-/bin/zsh}

# Every logical plugin, in the order the aggregate loads them.
typeset -ga LOGICAL=( prompt battery-prompt dns eternal-terminal git-alias git-worktree macos )

ok()   { (( PASS++ )); print -r  -- "  ok    $1" }
bad()  { (( FAIL++ )); print -ru2 -- "  FAIL  $1"; [[ -n ${2-} ]] && print -ru2 -- "        $2" }
eq()   { [[ $2 == $3 ]] && ok "$1" || bad "$1" "expected [$2], got [$3]" }
has()  { [[ $3 == *$2* ]] && ok "$1" || bad "$1" "[$3] does not contain [$2]" }
group(){ print -r -- "" ; print -r -- "$1" }

# Run zsh code in a pristine shell; prints stdout+stderr merged.
isolated() { zsh -f -c "$1" 2>&1 }

#
# 1. Every logical plugin loads on its own, silently.
#
group "sourcing each logical plugin in its own 'zsh -f'"
local p out
for p in $LOGICAL; do
  out=$(isolated "source $PLUGINS/$p/$p.plugin.zsh")
  eq "$p loads without printing anything" "" "$out"
done

#
# 2. The aggregate loads, silently, and exposes every public name.
#
group "aggregate entry point"
out=$(isolated "source $AGG")
eq "shell-plugins.plugin.zsh loads without printing anything" "" "$out"

# install_pkg and link_if_different come from the macos plugin, which defines
# nothing off Darwin on purpose — hdiutil, installer and com.apple.dock exist
# nowhere else. Asking for them on Linux tests the platform, not the package.
typeset -g PUBLIC='gw gwl gwa gwr gunwipall dns_records et _battery_prompt'
[[ $OSTYPE == darwin* ]] && PUBLIC+=' install_pkg link_if_different'

out=$(isolated "source $AGG
for f in $PUBLIC; do
  whence -w \$f >/dev/null || print -r -- \"missing: \$f\"
done
alias gwh >/dev/null || print -r -- 'missing alias: gwh'")
eq "every public function and alias is defined" "" "$out"

out=$(isolated "source $AGG; print -r -- \${\${(M)\$(whence -w gwa)}}")
has "gwa is a function" "function" "$out"

#
# 3. Loading is autoload-only: no function body is read at startup.
#
group "autoloading"
# An autoload-pending function has a stub body; the real one is only read on
# first call. That is the whole point of the layout.
out=$(isolated "source $AGG; functions gwa")
has "gwa is still undefined right after loading" "undefined" "$out"
out=$(isolated "source $AGG; gw >/dev/null; functions gwa")
has "gwa is still undefined after an unrelated command ran" "undefined" "$out"

#
# 4. Nothing forks during initialization.
#
group "no subprocesses at load time"
local shim=$(mktemp -d)
local c
for c in git brew nix dirname basename pwd sed awk find curl wget pmset dig \
         mktemp uname hostname tty date ls grep tr cut head tail; do
  print -r -- "#!/bin/sh
printf '%s\\n' \"\$0\" >> $shim/.calls
exit 1" > $shim/$c
  chmod +x $shim/$c
done
: > $shim/.calls
local calls
out=$(PATH=$shim $ZSH -f -c "source $AGG" 2>&1)
calls=$(<$shim/.calls)
eq "loading the aggregate prints nothing with an empty PATH" "" "$out"
eq "loading the aggregate runs no external command" "" "$calls"
for p in $LOGICAL; do
  : > $shim/.calls
  out=$(PATH=$shim $ZSH -f -c "source $PLUGINS/$p/$p.plugin.zsh" 2>&1)
  calls=$(<$shim/.calls)
  eq "$p runs no external command at load time" "" "$out$calls"
done
rm -rf $shim

#
# 5. No plugin initializes completion.
#
group "completion ownership"
out=$(isolated "compinit() { print -r -- 'compinit was called' }
compdef() { print -r -- 'compdef was called without compinit' }
unfunction compdef
source $AGG")
eq "no plugin calls compinit" "" "$out"

# With compinit already run (the legacy ordering), git-worktree registers its
# completions by hand rather than leaving them unreachable.
# "compinit has already run" means $_comps exists — that is the array it
# builds. A stubbed compdef is not the same claim, and must not trigger this.
out=$(isolated "typeset -gA _comps=()
typeset -ga REG=()
compdef() { REG+=( \"\$1:\$2\" ) }
source $PLUGINS/git-worktree/git-worktree.plugin.zsh
print -r -- \${(j:,:)REG}")
eq "git-worktree wires up compdef when compinit already ran" "_gwa:gwa,_gwl:gwl,_gwr:gwr" "$out"

out=$(isolated "typeset -ga REG=()
compdef() { REG+=( \"\$1:\$2\" ) }
source $PLUGINS/git-worktree/git-worktree.plugin.zsh
print -r -- \"[\${(j:,:)REG}]\"")
eq "a compdef stubbed before compinit does not" "[]" "$out"

# Dynamic modules are the only thing at this scale that costs real time:
# zsh/zutil is around 3.5ms, zsh/parameter 0.3ms, and each is paid once per
# shell whether or not the feature that wanted one is ever used. So nothing
# may load one while a plugin loads — not `zstyle`, not `$functions`, not
# `$commands`. Load them inside the function that needs them.
out=$(isolated "before=\$(zmodload | wc -l)
source $AGG
after=\$(zmodload | wc -l)
print -r -- \$(( after - before ))")
eq "loading the aggregate loads no dynamic module" "0" "$out"

for p in $LOGICAL; do
  out=$(isolated "before=\$(zmodload | wc -l)
source $PLUGINS/$p/$p.plugin.zsh
after=\$(zmodload | wc -l)
print -r -- \$(( after - before ))")
  eq "$p loads no dynamic module" "0" "$out"
done

# With the documented ordering, compinit finds the #compdef files on fpath.
out=$(isolated "source $AGG
autoload -Uz compinit
compinit -u -D
print -r -- \"gwa=\$_comps[gwa] gwl=\$_comps[gwl] gwr=\$_comps[gwr]\"")
eq "compinit picks up the completions from fpath" "gwa=_gwa gwl=_gwl gwr=_gwr" "$out"

#
# 5b. git-alias takes the names it defines, whatever held them first.
#
# ohmyzsh's git plugin defines gwip as an alias and gunwipall as a function.
# An alias outranks a function, and `autoload` does nothing to a name that is
# already a function, so without the unalias/unfunction in the plugin both of
# ours are unreachable and nothing says so.
#
group "git-alias claims its names"
# gwip: theirs is an alias, and an alias outranks a function whichever loaded
# last, so ours is unreachable until the alias goes.
out=$(isolated "alias gwip='print -r -- THEIRS'
source $PLUGINS/git-alias/git-alias.plugin.zsh
whence -w gwip")
eq "gwip is ours, not the alias that held the name" "gwip: function" "$out"

# gunwipall: theirs is a function, and `autoload` does nothing to a name that
# is already one. `whence -w` says "function" either way, so read the body --
# ours is an autoload stub until first call, theirs is not.
out=$(isolated "gunwipall() { print -r -- THEIRS }
source $PLUGINS/git-alias/git-alias.plugin.zsh
functions gunwipall")
has "gunwipall is ours, not the function that held the name" "undefined" "$out"

# The usual case: nothing held them, and clearing them says nothing.
out=$(isolated "source $PLUGINS/git-alias/git-alias.plugin.zsh")
eq "clearing names that were never taken prints nothing" "" "$out"

#
# 6. The prompt.
#
group "prompt"
out=$(isolated "source $PLUGINS/prompt/prompt.plugin.zsh; print -rn -- \${(V)PROMPT}")
eq "PROMPT is the two-line Pure-like string" \
   '\n%F{blue}%~%f\n%(?.%F{magenta}❯.%F{red}❯)%f ' "$out"

out=$(isolated "source $PLUGINS/prompt/prompt.plugin.zsh; cd /tmp; true; print -rn -P -- \"\$PROMPT\"" | cat -v)
has "success prompt renders in magenta" '^[[35m' "$out"
has "success prompt shows the directory in blue" '^[[34m/tmp' "$out"

out=$(isolated "source $PLUGINS/prompt/prompt.plugin.zsh; cd /tmp; false; print -rn -P -- \"\$PROMPT\"" | cat -v)
has "failure prompt renders in red" '^[[31m' "$out"

out=$(isolated "source $PLUGINS/prompt/prompt.plugin.zsh; print -r -- \"[\$RPROMPT]\"")
eq "the prompt plugin clears RPROMPT" "[]" "$out"

out=$(isolated "source $PLUGINS/prompt/prompt.plugin.zsh; [[ -o prompt_subst ]] && print -r -- on || print -r -- off")
eq "the prompt does not need PROMPT_SUBST" "off" "$out"

#
# 7. battery-prompt is opt-in.
#
group "battery-prompt"
out=$(isolated "source $AGG; print -r -- \"[\$RPROMPT]\"")
eq "battery-prompt stays out of RPROMPT by default" "[]" "$out"

out=$(isolated "zstyle ':battery-prompt:' show yes
source $AGG
print -r -- \"\$RPROMPT\"")
eq "battery-prompt joins RPROMPT when asked" '${_battery_prompt_cache_output}' "$out"

# A parameter expansion, not a command substitution: zsh expands ${...} itself,
# where $(...) forks a subshell before every prompt. This is the assertion that
# keeps that from quietly coming back.
hasnt "battery-prompt does not fork per prompt" '$(' "$out"

out=$(isolated "zstyle ':battery-prompt:' show yes
source $AGG
print -r -- \"\${precmd_functions[(r)_battery_prompt_precmd]}\"")
eq "battery-prompt renders from precmd" "_battery_prompt_precmd" "$out"

out=$(isolated "source $AGG; _battery_prompt >/dev/null; print -r -- \$?")
eq "_battery_prompt succeeds when called by hand" "0" "$out"

#
# 8. The commands behave outside a repository / without their tools.
#
group "command behaviour"
out=$(cd / && isolated "source $AGG; gw" | head -1 | cat -v)
has "gw prints its help on stdout" "git worktree helpers" "$out"

out=$(isolated "source $AGG; dns_records >/dev/null 2>&1; print -r -- \$?")
eq "dns_records without an argument exits 2" "2" "$out"

local nodig=$(mktemp -d)
out=$(PATH=$nodig $ZSH -f -c "source $AGG; dns_records example.com 2>/dev/null; print -r -- \$?")
eq "dns_records without dig exits 127" "127" "$out"
rm -rf $nodig

local fakebin=$(mktemp -d)
print -r -- '#!/bin/sh
exit 42' > $fakebin/et
chmod +x $fakebin/et
out=$(PATH=$fakebin:$PATH $ZSH -f -c "source $AGG; et --whatever >/dev/null; print -r -- \$?")
eq "et forwards the exit status of the real et" "42" "$out"
out=$(PATH=$fakebin:$PATH $ZSH -f -c "source $AGG; et --whatever" | cat -v)
eq "et resets the terminal before and after" \
   '^[[?1049l^[[?1047l^[[?47l^[[?1l^[[?1000l^[[?1002l^[[?1003l^[[?1006l^[[?1007l^[[?1049l^[[?1047l^[[?47l^[[?1l^[[?1000l^[[?1002l^[[?1003l^[[?1006l^[[?1007l' \
   "$out"
rm -rf $fakebin

local norepo=$(mktemp -d)
out=$(cd $norepo && isolated "source $AGG; gunwipall 2>/dev/null; print -r -- \$?")
eq "gunwipall outside a repository exits 1" "1" "$out"
out=$(cd $norepo && isolated "source $AGG; gwl 2>&1 >/dev/null; print -r -- \$?" | tail -1)
eq "gwl outside a repository exits 1" "1" "$out"
rm -rf $norepo

#
# 9. Repository structure.
#
group "structure"
for p in $PLUGINS/*(/); do
  local n=${p:t}
  [[ -f $p/$n.plugin.zsh ]] && ok "$n has exactly one obvious entry point" \
    || bad "$n has no $n.plugin.zsh"
  (( ${LOGICAL[(Ie)$n]} )) && ok "$n is listed in the aggregate" \
    || bad "$n is not loaded by shell-plugins.plugin.zsh"
done

# Every file under functions/ must actually end up autoloadable, and every
# autoload declaration must have a file behind it. Asked of a live shell —
# an autoload-pending function has `builtin autoload -X` for a body — rather
# than by parsing the plugin text.
for p in $PLUGINS/*(/); do
  [[ -d $p/functions ]] || continue
  if [[ ${p:t} == macos && $OSTYPE != darwin* ]]; then
    ok "macos: autoloads nothing off Darwin, as the plugin says it will"
    continue
  fi
  local -a declared files missing extra
  declared=( ${(f)"$(isolated "source $p/${p:t}.plugin.zsh
    for f in \${(k)functions}; do
      [[ \${functions[\$f]} == *'autoload -X'* ]] && print -r -- \$f
    done")"} )
  declared=( ${declared:#} )
  files=( $p/functions/*(:t) )
  missing=( ${files:|declared} )
  extra=( ${declared:|files} )
  if (( $#missing || $#extra )); then
    (( $#missing )) && bad "${p:t}: functions/ files that are never autoloaded: ${(j:, :)missing}"
    (( $#extra ))   && bad "${p:t}: autoloaded without a functions/ file: ${(j:, :)extra}"
  else
    ok "${p:t}: all $#files functions/ files autoload, and nothing else does"
  fi
done

# A `local path` empties $PATH for the length of the call, so nothing external
# can be found inside the function — and zsh says nothing about it. The same
# trap is set by fpath, cdpath, manpath, status, prompt and the rest of the
# tied or behavioural specials, so the list is asked of zsh itself rather than
# written down here and left to rot.
group "shadowed special parameters"
# (#b) and # are EXTENDED_GLOB constructs; `emulate -L zsh` leaves it off, and
# without it the pattern below matches nothing and this test passes vacuously.
setopt local_options extended_glob
local -a specials allowed offenders
specials=( ${(f)"$(zsh -f -c 'print -rl -- ${(k)parameters}')"} )
# Deliberate, and safe: these are the ones a zsh function is *meant* to write
# to or receive in.
allowed=( REPLY reply MATCH match MBEGIN mbegin MEND mend )
specials=( ${specials:|allowed} )

local file line word name
for file in $PLUGINS/*/functions/*(N) $PLUGINS/*/completions/*(N) $AGG $PLUGINS/*/*.plugin.zsh(N); do
  for line in ${(f)"$(<$file)"}; do
    [[ $line == (#b)[[:space:]]#(local|typeset|declare)[[:space:]]* ]] || continue
    for word in ${(z)line}; do
      case $word in
        local|typeset|declare|-*) continue ;;
      esac
      name=${word%%=*}
      [[ $name == [A-Za-z_][A-Za-z0-9_]# ]] || continue
      (( ${specials[(Ie)$name]} )) && offenders+=( "${file:t}: $name" )
    done
  done
done
if (( $#offenders )); then
  local o
  for o in ${(u)offenders}; do bad "declares a local named after a zsh special: $o"; done
else
  ok "no function shadows a zsh special parameter"
fi

print -r -- ""
print -r -- "zsh: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
