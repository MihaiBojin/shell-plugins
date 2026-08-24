# Plugins

One Git repository, several logical plugins. The repository is the unit you
install; the plugins are the feature boundaries inside it.

| Feature | Zsh | Fish | Purpose |
|---|---|---|---|
| prompt | `zsh/plugins/prompt` | `functions/fish_prompt.fish` | Minimal two-line Pure-like prompt |
| battery-prompt | `zsh/plugins/battery-prompt` | `functions/fish_right_prompt.fish` | Battery status on the right, off by default |
| git-alias | `zsh/plugins/git-alias` | `functions/{gwip,gunwip,gunwipall}.fish` | The short git and `gh` commands, and the three wip ones |
| macos | `zsh/plugins/macos` | — | Provisioning helpers for setting a Mac up |
| git-worktree | `zsh/plugins/git-worktree` | — | `gw`/`gwl`/`gwa`/`gwr` worktree helpers |
| dns | `zsh/plugins/dns` | `functions/dns_records.fish` | `dns_records` — dump a domain's common records |
| eternal-terminal | `zsh/plugins/eternal-terminal` | `functions/et.fish` | `et` wrapper that unsticks the terminal after a drop |

## Public commands

| Command | Shells | Requires | What it does |
|---|---|---|---|
| `gw`, `gwh` | zsh | — | Print the git-worktree help |
| `gwl [QUERY]` | zsh | `git`, `fzf` (optional) | Pick a worktree and `cd` into it |
| `gwa NAME [BASE]` | zsh | `git` | Create a worktree on branch `NAME` and `cd` into it |
| `gwr [PATH\|QUERY]` | zsh | `git`, `gh`/`glab` (optional) | Remove a worktree whose branch is finished, and the branch with it |
| `gwr --all [--yes]` | zsh | `git`, `gh`/`glab` (optional) | The same, to every finished worktree at once |
| `ga` `gc` `gca` `gca!` `gcan!` `gco` `gcb` `gcm` `gst` `gd` `gdca` `gcp` `gcpc` `gcpa` `gp` `gpsup` `gmom` `gwip` `gunwip` `gpa!` `gcap` | zsh | `git` | The short git commands |
| `gh-login` `gh-add-key` | zsh | `gh` | Authenticate a new machine with GitHub over SSH |
| `gwip` | zsh, fish | `git` | Commit everything as `--wip-- [skip ci]`, unsigned and unverified |
| `gunwip` | zsh, fish | `git` | Undo the last commit if it is a `--wip--` |
| `gunwipall` | zsh, fish | `git` | Reset onto the newest non-`--wip--` commit |
| `install_pkg` `install_dmg_pkg` `install_dmg` `install_app_zip` | zsh | macOS, `curl`, `sudo` | Install something from a URL |
| `backup_if_exists` `link_if_different` | zsh | macOS | Symlink a file, keeping whatever was there |
| `clone_repo` | zsh | macOS, `gh` | Clone a repository, or bring it up to date |
| `_add_dock_persistent_app` `_add_dock_spacer` `_delete_dock_apps` | zsh | macOS | Rearrange the Dock |
| `dns_records DOMAIN` | zsh, fish | `dig` | Print A/AAAA/CNAME/TXT/NS/MX/CAA/SRV records |
| `et [ARGS...]` | zsh, fish | `et` | Run Eternal Terminal with the terminal state reset around it |
| `_battery_prompt` | zsh | `pmset` (macOS) or sysfs (Linux) | Render the battery segment (called by the prompt) |
| `_shell_battery_prompt` | fish | `pmset` (macOS) or sysfs (Linux) | The same for Fish; `fish_right_prompt` calls it once enabled |

Everything except the prompt is autoloaded — Zsh through `fpath` + `autoload
-Uz`, Fish through its own function autoloading — so none of it is read, parsed
or executed until you type the command.

## Parity between the shells

Same names, same behaviour, separate implementations. Nothing is shared between
the two shells at the source level, on purpose: the syntax and the runtime
models differ enough that a common layer costs more than it saves.

Two features are **Zsh only**, and one is partly so:

- **git-alias** — partly. `gwip`, `gunwip` and `gunwipall` are functions, so
  Fish autoloads them and both shells have them. The rest are aliases, and the
  Fish equivalent of an alias worth having is an abbreviation, which has to be
  declared at startup — that means `conf.d/`, and it stays empty.
- **macos** — provisioning, run by hand on a new machine, and the Fish
  configuration has never had it.
- **git-worktree** — around 1600 lines of Zsh with its own `zstyle`
  configuration surface, an fzf picker and a spinner. A faithful Fish port is a
  project in its own right, not a mechanical translation, and the current Fish
  configuration has never had these commands. Adding them there would be new
  functionality rather than a migration, so it is deliberately left out. If the
  Fish side ever needs them, the honest options are a real port or a small
  standalone binary that both shells wrap.

Both are noted in the tables above with `—` rather than silently omitted.

**battery-prompt** has both. The Zsh segment appends to `RPROMPT`; the Fish one
*is* `fish_right_prompt`, which the package therefore owns — the same way it
owns `fish_prompt`. Both are off until asked for (`zstyle … show yes` in Zsh,
`set shell_battery_prompt_show yes` in Fish), and neither reads a battery until
then.

## What is *not* here, and why

These stay in the consuming dotfiles/config repository.

- Shell options, history policy, `PATH` and environment configuration.
- Homebrew/Nix/system package setup, and anything that names a package prefix.
- Third-party plugin configuration (`zsh-abbr` abbreviations, autosuggestions
  tuning, `zephyr` styles) and the plugin managers themselves.
- Tool initialization: `mise`, `direnv`, `gpg-agent`, `starship`, OrbStack.
- Work-specific helpers, hostnames, and anything holding a credential.
- `zstyle` settings *for* these plugins: the plugin ships the default, the
  configuration chooses the value.

## conf.d policy

`conf.d/` is empty, and the aim is to keep it that way. Every file in it runs
during Fish startup, which is exactly the cost this repository exists to avoid.
Functions do not belong there — Fish autoloads them. Neither does the prompt.
A file only earns a place in `conf.d/` if it genuinely must run for every
interactive shell, and it has to say why in a comment at the top.

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

Fish completions belong in the repository-root `completions/`, checked in rather
than generated at startup. There are none yet: no current Fish function takes an
argument worth completing.
