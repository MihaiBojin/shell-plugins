# Development

## Running the tests

```sh
tests/run.sh
```

That is everything: `zsh -n`, `fish -n` and `bash -n` over every source file,
`shellcheck` over `bin/`, the isolated smoke tests for both shells and for the
scripts in `bin/`, and the repository hygiene checks. It skips whichever shell
is not installed rather than failing — a machine only ever needs one of them.

The pieces run standalone too:

```sh
zsh -f tests/zsh/smoke.zsh          # never sees your .zshrc
fish --no-config tests/fish/smoke.fish
sh tests/bin.sh                     # stubs pmset and uname on $PATH
```

Both suites spawn their own child shells for each case, so a plugin that leaks
state cannot hide behind one that loaded earlier.

### What the tests actually enforce

Beyond "does it work", they hold the contract in place:

- **No forks at load time.** The Zsh suite puts a directory of failing stubs
  (`git`, `brew`, `sed`, `curl`, `pmset`, …) at the front of an otherwise empty
  `PATH`, sources each plugin, and asserts the stub log is empty and nothing was
  printed.
- **No `compinit`.** A stub `compinit` is installed before loading; it must
  never be called. A second case runs the real `compinit` afterwards and asserts
  the `#compdef` files were picked up from `$fpath`.
- **Autoload, not source.** Every file under a plugin's `functions/` must end up
  autoload-*pending* after the plugin loads — checked by looking at the live
  function body, not by parsing the plugin text — and nothing may be declared
  that has no file.
- **Silence.** Loading any plugin, or the aggregate, must print nothing at all.
- **Fisher layout.** The Fish suite copies `functions/`, `conf.d/` and
  `completions/` into a throwaway `$XDG_CONFIG_HOME/fish`, then asserts every
  function is discoverable there by autoloading alone, with no `config.fish`
  anywhere. Those directories are also all Fisher copies, which is why `bin/`
  is not part of the Fish package and needs a `$PATH` line instead.
- **`bin/` is executable and behaves.** `battery` keys off pmset's presence
  rather than the operating system and `macos` asks `uname -s`, so both can be
  driven from either platform with a stub in front. A file in `bin/` that is not
  executable fails the repository checks: it would be on `$PATH` and unusable,
  and the only sign of it is "command not found" from a file you can see.
- **No leakage.** No machine-specific absolute path, credential-shaped string,
  or package-manager call in shipped code.

> `zsh -n` is a parse check, not a dry run, but it *does* expand `$(<file)` — so
> a syntax check can print a "no such file" for a path that does not exist yet.
> The suite treats any output from `zsh -n` as a failure, so read from a file
> into a scalar first and split afterwards.

## What it costs to load

One `source` per fresh `zsh -f`, warm cache, median of 125, in a shell with
nothing loaded but the clock the measurement needs. 125 rather than a couple of
dozen because at this scale a run of 25 swings by more than the figures differ
from each other: two blocks of 125 agree to 0.02 ms, two blocks of 25 do not.

| | Load |
|---|---|
| **aggregate** | **0.68 ms** |
| prompt | 0.09 ms |
| bin | 0.26 ms |
| dns | 0.20 ms |
| eternal-terminal | 0.20 ms |
| git-alias | 0.32 ms |

```zsh
zmodload zsh/datetime
typeset -F t0=$EPOCHREALTIME
source shell-plugins.plugin.zsh
print -f "%.4f ms\n" $(( ($EPOCHREALTIME - t0) * 1000 ))
```

The per-plugin figures do not add up to the aggregate, and that is not an
error. Each one measured alone pays about 0.10 ms of once-per-shell setup — the
first prompt expansion, the first `fpath` write, the `source` machinery — which
the plugins in one shell pay once between them. The aggregate is the number
that describes a real startup.

Most of a plugin's figure is the first `${(%):-%x}` in the shell, around
0.10 ms paid once however many plugins ask, plus the `source` machinery and the
parse. The autoload declarations are the cheapest part: `autoload` writes a stub
and reads nothing, so the file behind each name is opened the first time that
command is typed, not at startup.

### Dynamic modules

They are the only thing at this scale that costs real time, and each is paid
once per shell whether or not the feature that wanted one is ever used:

| Module | Load | Wanted by |
|---|---|---|
| `zsh/zutil` | 3.5 ms | `zstyle` |
| `zsh/parameter` | 0.3 ms | `$functions`, `$commands`, `$builtins` |
| `zsh/datetime` | 0.3 ms | `$EPOCHSECONDS` |
| `zsh/zselect` | 0.2 ms | `zselect` |

So no plugin loads one while it loads. A smoke test asserts that, per plugin
and for the aggregate, by counting `zmodload` output before and after.

Where each is loaded instead:

- `zsh/zselect` — not at all. Nothing here calls `zselect`.
- `zsh/parameter` — not at all at load time. The "has compinit run" test reads
  `$_comps`, the array compinit builds, rather than `$functions`.
- `zsh/zutil` — not at all. No plugin here reads a `zstyle`.
- `zsh/datetime` — not at all. Nothing here needs a clock any more.

On the Fish side the only startup cost is `conf.d/git-alias.fish`: twenty-nine
`abbr` calls, 0.22 ms, no forks.

Keep it that way. If a change pushes the aggregate materially past its measured figure,
something is being done at load time that belongs in a function.

## Adding a Zsh plugin

```text
zsh/plugins/<name>/
├── <name>.plugin.zsh      # the one obvious entry point
├── functions/<command>    # one function per file, filename == function name
├── completions/_<command> # starts with "#compdef <command>"
└── README.md              # if it has a configuration surface
```

The entry point may do only cheap things:

```zsh
fpath=( ${${(%):-%x}:A:h}/functions ${${(%):-%x}:A:h}/completions $fpath )
autoload -Uz <command> <helpers...>
```

`${${(%):-%x}:A:h}` is the plugin's own directory, resolved by Zsh's prompt
expansion — no `dirname`, no `pwd`, no subshell. It works at the top level of a
sourced file and inside an anonymous function.

The entry point must not fork, glob large trees, call `compinit`, or touch the
network. Then add the plugin to `shell-plugins.plugin.zsh` (by hand — the list
is explicit on purpose) and to the `LOGICAL` array in `tests/zsh/smoke.zsh`.
Both are asserted, so forgetting either fails the suite.

Private globals get a short namespaced prefix (`_GW_*`); everything else is
`local`.

## Adding a command to bin/

A command belongs in `bin/` when it never touches the shell it was typed in —
no `cd`, no exported variable, no alias, nothing read back from the caller's
state. Then it can be one bash script instead of two shell implementations, and
both shells run the same file.

Bash 3.2, which is what macOS ships: no associative arrays, no `${var,,}`.
`set -euo pipefail`, `shellcheck`-clean, executable in Git, and a `--help` that
says what it does. Add the cases to `tests/bin.sh`, which stubs the commands
that would otherwise download, mount or install something.

Anything that must change the caller's shell stays a function, in both shells.

## Adding a Fish function

One public function per file, `functions/<name>.fish`, defining a function
called exactly `<name>` — that is how Fish autoloads it, and the test suite
checks it. Private helpers are prefixed `_shell_`, because Fish's installed
function namespace is flat.

Nothing goes in `conf.d/` unless it genuinely must run for every interactive
shell, and then it says why at the top of the file.

## Conventions

- The two shells share no source. Same command names and behaviour, separate
  implementations — see [PLUGINS.md](PLUGINS.md#parity-between-the-shells).
- Comments explain *why*. What the code does is visible; the reason it is
  written that way is not.
- Configuration is `zstyle` in Zsh, read at call time where practical so it can
  be changed without reloading.
- Defaults never cost anything at startup. Anything with a per-prompt or
  per-command price is opt-in.

## Releasing

Tag with a plain semantic version and push the tag:

```sh
git tag -a v0.1.0 -m "…"
git push origin v0.1.0
```

Consumers pin from their own configuration ([README](../README.md#pinning));
nothing is pinned inside this repository.
