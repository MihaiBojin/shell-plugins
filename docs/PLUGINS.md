# Plugins

One Git repository, several logical plugins. The repository is the unit you
install; the plugins are the feature boundaries inside it.

| Feature | Zsh | Fish | Purpose |
|---|---|---|---|
| prompt | `zsh/plugins/prompt` | `functions/fish_prompt.fish` | Minimal two-line Pure-like prompt |
| git-alias | `zsh/plugins/git-alias` | `conf.d/git-alias.fish`, `functions/{gb!,gbd!,gcm,gcm!,gup}.fish` | The short git and `gh` commands, the two pickers, and the three that announce |
| dns | `zsh/plugins/dns` | `functions/dns_records.fish` | `dns_records` — dump a domain's common records |
| eternal-terminal | `zsh/plugins/eternal-terminal` | `functions/et.fish` | `et` wrapper that unsticks the terminal after a drop |
| bin | `zsh/plugins/bin` | one `fish_add_path` line | Puts `bin/` on `$PATH`, for the commands that are not shell code |

The last row is the odd one: `bin/` holds two bash scripts, `battery` and
`macos`, which print and exit without touching the shell. `macos` asks for
Darwin per command, not once at the top: `backup-if-exists`,
`link-if-different` and `clone-repo` are ordinary file and git work, and a
Linux machine being provisioned calls them too. One implementation
then serves both shells. Zsh reaches them through the plugin; Fish needs a line
in `config.fish`, because Fisher only copies `functions/`, `conf.d/`,
`completions/` and `themes/`. See the
[README](../README.md#commands-on-path).

## Public commands

| Command | Shells | Requires | What it does |
|---|---|---|---|
| `ga` `gaa` `gc` `gca` `gca!` `gcan!` `gb` `gco` `gcb` `gst` `gd` `gdca` `gcp` `gcpc` `gcpa` `gfa` `gp` `gpsup` `gmom` `gmc` `gma` `grbom` `grbc` `grba` `gpa!` `gcap` | zsh, fish | `git` | The short git commands |
| `gcm [ARGS...]` | zsh, fish | `git` | Check out the default branch, naming it first |
| `gup [ARGS...]` | zsh, fish | `git` | Fetch every remote and prune, then `git pull --rebase` |
| `gcm!` | zsh, fish | `git` | `gcm` then `gup`, stopping at the first failure |
| `gb! [QUERY]` | zsh, fish | `git`, `fzf` (optional) | Pick a branch and check it out. `gb` itself is plain `git branch` |
| `gbd! [QUERY]` | zsh, fish | `git`, `fzf` (optional) | Delete branches, having said first whether each one is merged, squash-merged, or held by another ref |
| `gh-login` `gh-add-key` | zsh, fish | `gh` | Authenticate a new machine with GitHub over SSH |
| `macos install-pkg` `install-dmg-pkg` `install-dmg` `install-app-zip` | `$PATH` | macOS, `curl`, `sudo` | Install something from a URL |
| `macos backup-if-exists` `link-if-different` | `$PATH` | — | Symlink a file, keeping whatever was there |
| `macos clone-repo` | `$PATH` | `git`, `gh` | Clone a repository, or bring it up to date |
| `macos dock add-app` `add-spacer` `clear` | `$PATH` | macOS | Rearrange the Dock |
| `dns_records DOMAIN` | zsh, fish | `dig` | Print A/AAAA/CNAME/TXT/NS/MX/CAA/SRV records |
| `et [ARGS...]` | zsh, fish | `et` | Run Eternal Terminal with the terminal state reset around it |
| `battery [--percent]` | `$PATH` | `pmset` (macOS) or sysfs (Linux) | Print the charge, once |

Everything except the prompt and Fish's abbreviations is autoloaded — Zsh
through `fpath` + `autoload -Uz`, Fish through its own function autoloading — so
none of it is read, parsed or executed until you type the command. The
abbreviations are the exception because they cannot be: one has to exist before
you type the word it expands. The two `$PATH` commands are not loaded at all:
they are separate processes, read only when you run them.

## Parity between the shells

Same names, same behaviour, separate implementations. Nothing is shared between
the two shells at the source level, on purpose: the syntax and the runtime
models differ enough that a common layer costs more than it saves.

Every feature is in both shells. Two commands sidestep the question entirely:

- **git-alias** — both shells. Five are functions in both: the `gb!` and `gbd!`
  pickers, and `gcm`, `gcm!` and `gup`, which print the command they are about
  to run because the default branch in it is not known early enough to expand.
  The rest are Zsh aliases and Fish abbreviations, which is the closer
  equivalent anyway: an abbreviation expands where you can see it. Declaring one
  means `conf.d/`, which is why that directory is not empty — about 0.2ms at
  every Fish start, and the only thing in the package that is not autoloaded.
- **The worktree commands** — neither shell, and not here. They live in
  [MihaiBojin/worktrees](https://github.com/MihaiBojin/worktrees): one Python
  package, `git-worktrees` on PyPI, shipping the four commands that `cd` their
  caller as shell functions beside the binaries. One implementation serves both
  shells, where this package carried two.
- **`battery` and `macos`** — neither shell, which is the point. They print and
  exit without touching the shell, so they are bash scripts in `bin/` and there
  is only one copy of each. The cost is the `$PATH` line Fish needs, and that
  `fisher install` alone does not deliver them.

## What is *not* here, and why

These stay in the consuming dotfiles/config repository.

- Shell options, history policy and environment configuration. `PATH` too,
  except for the one entry that makes this repository's own `bin/` reachable.
- Homebrew/Nix/system package setup, and anything that names a package prefix.
- Third-party plugin configuration (`zsh-abbr` abbreviations, autosuggestions
  tuning, `zephyr` styles) and the plugin managers themselves.
- Tool initialization: `mise`, `direnv`, `gpg-agent`, `starship`, OrbStack.
- Work-specific helpers, hostnames, and anything holding a credential.
- `zstyle` settings *for* these plugins: the plugin ships the default, the
  configuration chooses the value.

## conf.d policy

`conf.d/` holds one file, `git-alias.fish`, and one is the target. Every file in
it runs during Fish startup, which is exactly the cost this repository exists to
avoid. Functions do not belong there — Fish autoloads them. Neither does the
prompt. An abbreviation does: declared inside an autoloaded function file it
only appears once something else has caused that file to load, so there is
nowhere else it can go. A second file only earns a place if it genuinely must
run for every interactive shell, and it has to say why in a comment at the top.
A smoke test asserts the current contents, so adding one is deliberate.

## Completions

Zsh completions live beside the plugin that owns them
(`zsh/plugins/<name>/completions/`) and are registered by putting that directory
on `$fpath`. **No plugin here calls `compinit`** — that belongs to the consuming
configuration, which must run it once, after every plugin has loaded:

```text
plugin repository → register functions/ and completions/ on $fpath
                          ↓
        consuming configuration → compinit, once
```

Fish completions live in the repository-root `completions/`, checked in rather
than generated at startup, and Fish autoloads one the first time you press Tab
on that command rather than at login. `gb!` and `gbd!` have one each, offering
branch names: every branch for `gb!`, only the local ones for `gbd!`, since
only those can be deleted.
