# shell-plugins

First-party Zsh and Fish plugins, in one repository.

- **Zsh** consumers load it with [Antidote](https://antidote.sh) — all of it, or
  one feature at a time.
- **Fish** consumers install it with [Fisher](https://github.com/jorgebucaran/fisher)
  as a single native package.

Everything is autoloaded. Loading the whole collection defines no function
bodies, runs no external command, starts no background work, and prints nothing;
the first time you type one of the commands is the first time its file is read.

Two of the commands are bash scripts on `$PATH` rather than shell code, because
they print and exit and both shells can run the same file: see
[Commands on `$PATH`](#commands-on-path).

What is in it: [`docs/PLUGINS.md`](docs/PLUGINS.md).
How to work on it: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## Install — Zsh, everything

Add one line to your Antidote bundle file:

```text
MihaiBojin/shell-plugins
```

Antidote finds `shell-plugins.plugin.zsh` at the repository root, which loads
every first-party plugin in a fixed order.

## Install — Zsh, selected features

Or name the features you want, and control the order yourself:

```text
MihaiBojin/shell-plugins path:zsh/plugins/prompt
MihaiBojin/shell-plugins path:zsh/plugins/git-alias
MihaiBojin/shell-plugins path:zsh/plugins/dns
MihaiBojin/shell-plugins path:zsh/plugins/eternal-terminal
MihaiBojin/shell-plugins path:zsh/plugins/bin
```

Both forms are supported and will stay supported. Every plugin also works when
sourced on its own, with no configuration:

```zsh
source /path/to/shell-plugins/zsh/plugins/prompt/prompt.plugin.zsh
```

Order does not matter: no plugin here reads or writes anything another one
sets.

### What your configuration still owns

These plugins register their `functions/` and `completions/` directories on
`$fpath` and stop there. **They never call `compinit`.** Run it once yourself,
*after* the plugins have loaded, or their completions will not be found:

```zsh
# … load plugins …
autoload -Uz compinit && compinit
```

Everything else that is not reusable shell behaviour — history, shell options,
tool initialization, the plugin manager itself — stays in your configuration
too. `PATH` as well, with one exception: the `bin` plugin appends this
repository's own `bin/` to it, because there is no `fpath` equivalent for an
executable. See [Commands on `$PATH`](#commands-on-path).

## Install — Fish

```fish
fisher install MihaiBojin/shell-plugins
```

The repository root *is* the Fisher package: `functions/`, `conf.d/` and
`completions/` are where Fisher expects them, so there is no build step and no
loader to source. Fish autoloads the functions natively.

Fisher records it in `~/.config/fish/fish_plugins`, which you can also edit
directly and then run `fisher update`:

```text
jorgebucaran/fisher
MihaiBojin/shell-plugins
```

`conf.d/` holds one file, `git-alias.fish`, and holding it to one is
deliberate: everything in that directory runs at every interactive Fish start.
An abbreviation has to be declared there or it does not exist, which is why
that one is allowed. Everything else in the package is autoloaded and costs
nothing until you type its name.

## Commands on `$PATH`

Two things here are not shell code at all — bash scripts that print and exit,
so a single implementation serves both shells:

| | |
|---|---|
| `battery` | The charge, once, when you ask for it |
| `macos` | Provisioning helpers for setting a Mac up |

Zsh gets them from the `bin` plugin, which appends `bin/` to `$PATH`; loading
the whole collection includes it.

Fish needs one line, because Fisher only ever copies `functions/`, `conf.d/`,
`completions/` and `themes/` — a repository-root `bin/` is not part of the
package it installs. Clone the repository and point at it:

```fish
fish_add_path ~/git/MihaiBojin/shell-plugins/bin
```

## Pinning

For machines that should not move until you say so, pin from the *consuming*
configuration — nothing is pinned inside this repository.

Fisher takes a tag, branch or commit after `@`:

```text
MihaiBojin/shell-plugins@v0.1.0
```

Antidote takes a branch or tag, and a commit for strict reproducibility:

```text
MihaiBojin/shell-plugins branch:v0.1.0
MihaiBojin/shell-plugins path:zsh/plugins/prompt branch:v0.1.0
```

Releases are ordinary Git tags: `v0.1.0`, `v0.2.0`, …

## Requirements

Git, plus Zsh with Antidote or Fish with Fisher. Nothing here assumes macOS,
Homebrew, Nix, a particular terminal, a username, or a home directory.

Individual commands use external tools on purpose, and say so when they are
missing: `git` (and optionally `fzf`) for the branch pickers, `dig` for
`dns_records`, `et` for the Eternal Terminal wrapper, `pmset` or Linux sysfs for
`battery`, and bash 3.2 or newer for `battery` and `macos`.

## Tests

```sh
tests/run.sh
```

## License

Apache-2.0. See [LICENSE](LICENSE).
