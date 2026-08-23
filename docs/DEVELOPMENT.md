# Development

## Running the tests

```sh
tests/run.sh
```

That is everything: `zsh -n` and `fish -n` over every source file, the isolated
smoke tests for both shells, and the repository hygiene checks. It skips
whichever shell is not installed rather than failing — a machine only ever needs
one of them.

The pieces run standalone too:

```sh
zsh -f tests/zsh/smoke.zsh          # never sees your .zshrc
fish --no-config tests/fish/smoke.fish
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
  anywhere.
- **No leakage.** No machine-specific absolute path, credential-shaped string,
  or package-manager call in shipped code.

> `zsh -n` is a parse check, not a dry run, but it *does* expand `$(<file)` — so
> a syntax check can print a "no such file" for a path that does not exist yet.
> The suite treats any output from `zsh -n` as a failure, so read from a file
> into a scalar first and split afterwards.

## What it costs to load

One `source` per fresh `zsh -f`, warm cache, median of 25, in a shell with
nothing loaded but the clock the measurement needs.

| | Load |
|---|---|
| **aggregate, all seven** | **1.02 ms** |
| prompt | 0.10 ms |
| battery-prompt | 0.26 ms |
| dns | 0.23 ms |
| eternal-terminal | 0.23 ms |
| git-alias | 0.30 ms |
| git-worktree | 0.31 ms |
| macos | 0.25 ms |

```zsh
zmodload zsh/datetime
typeset -F t0=$EPOCHREALTIME
source shell-plugins.plugin.zsh
print -f "%.4f ms\n" $(( ($EPOCHREALTIME - t0) * 1000 ))
```

The per-plugin figures do not add up to the aggregate, and that is not an
error. Each one measured alone pays about 0.15 ms of once-per-shell setup — the
first prompt expansion, the first `fpath` write, the `source` machinery — which
seven plugins in one shell pay once between them. The aggregate is the number
that describes a real startup.

Where git-worktree's 0.32 ms goes, it being the largest:

| | |
|---|---|
| the first `${(%):-%x}` in the shell | 0.10 ms, once however many plugins ask |
| `source` machinery, and parsing 60 lines | 0.09 ms |
| `fpath=( … $fpath )` | 0.03 ms |
| `autoload -Uz` × 40 | 0.03 ms |
| seven `typeset -g` | 0.01 ms |

Forty autoload declarations are the cheapest thing in it. `autoload` writes a
stub and reads nothing; the file behind each name is opened the first time that
command is typed.

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

- `zsh/datetime`, inside `_battery_prompt` on first render.
- `zsh/zselect`, inside `_gw_run` on first use.
- `zsh/parameter` — not at all at load time. The "has compinit run" test reads
  `$_comps`, the array compinit builds, rather than `$functions`.
- `zsh/zutil` — not at all at load time. battery-prompt needs `zstyle` to know
  whether it was switched on, and asks only when `zmodload -e zsh/zutil` says
  the module is already there. That is not a guess: `zstyle` is a builtin from
  that module, so a style can only exist if something already loaded it. No
  module, no styles, and the defaults are already in place.

On the Fish side the number is zero by construction: `conf.d/` is empty, so
Fish runs none of this at startup.

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
