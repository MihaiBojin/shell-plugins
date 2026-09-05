# git-alias

The short git commands, defined here so the collection stands on its own, plus
two `gh` ones.

| Alias | Runs |
|---|---|
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gc` | `git commit --verbose` |
| `gca` | `git commit --verbose --all` |
| `gca!` | `git commit --verbose --all --amend` |
| `gcan!` | `git commit --verbose --all --no-edit --amend` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gcm` | `git checkout <default branch>` |
| `gst` | `git status` |
| `gd` | `git diff` |
| `gdca` | `git diff --cached` |
| `gcp` | `git cherry-pick` |
| `gcpc` | `git cherry-pick --continue` |
| `gcpa` | `git cherry-pick --abort` |
| `gp` | `git push` |
| `gpsup` | `git push --set-upstream origin <current branch>` |
| `gmom` | `git merge origin/<default branch>` |
| `gunwip` | Undo the last commit if it is a `--wip--` |
| `gpa!` | `add -A`, commit as "save all", push, status |
| `gcap` | The same, as `&&` rather than `;`, committed as "CommitAndPush" |
| `gh-login` | `gh auth login` over SSH, with the scopes a new machine needs |
| `gh-add-key` | Register `~/.ssh/id_ed25519.pub` with GitHub as an auth key |

Fish has the same set, as abbreviations in `conf.d/git-alias.fish` — the two
`gh` ones included. An abbreviation expands on the command line, so what runs is
what you can see before you press Return, and it lands in history spelled out;
that is what makes `gca!` reasonable to have on two keys.

It has to be `conf.d/`, not `functions/`: an abbreviation only exists once
something has declared it, and a declaration inside an autoloaded function file
runs only when something else has already loaded that file. So this is the one
part of the package that runs at every Fish start — twenty-two builtin calls,
0.19ms, no forks.

`gcm`, `gmom` and `gpsup` expand to a command substitution
(`git checkout (_git_alias_main_branch)`), so the repository is asked when the
line runs rather than when the shell started. The two helpers behind them are
autoloaded functions, same names as the Zsh ones.

`gwip` and `gunwipall` are functions rather than aliases, being loops:

| Command | What it does |
|---|---|
| `gwip` | Stage everything, deletions included, and commit it as `--wip-- [skip ci]` |
| `gunwipall` | Reset onto the newest commit whose **subject** is not a `--wip--`, dropping a whole run of them at once |

`gpa!` and `gcap` are the same idea twice. `gpa!` keeps going when a step
fails, which is ohmyzsh's behaviour and the reason the name is theirs; `gcap`
stops, so a rejected commit is not followed by a push.

`gh-login` and `gh-add-key` are not git. They are what a new machine needs
before git can talk to GitHub, and they are two lines, so they live here rather
than in a plugin of their own.

`!` means amend, following the convention the names come from. `gwip` and
`gunwip` park work in a commit that says it is unfinished; `gunwipall` takes
back every one of them rather than the last.

`gwip`, `gunwip` and `gunwipall` exist for Fish too, as
`functions/{gwip,gunwip,gunwipall}.fish` in this repository's Fish package —
they are functions, so Fish autoloads them and neither shell pays anything at
startup.

The aliases are Zsh only, but the names are not. The Fish equivalent of an
alias worth having is an abbreviation, and an abbreviation has to be declared at
startup — which means `conf.d/git-alias.fish`, the one file in the package that
is not autoloaded, at 0.19ms a shell.

## Where the rest of them are

These names are ohmyzsh's, and there are about three hundred more:

**<https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git>**

That page is the reference for anything not listed above — `grbi`, `gsta`,
`glog`, and the rest. Loading both is safe, and this one wins the names it
defines whichever loaded first.

That takes two lines of work rather than none, so it is worth saying why. Zsh
resolves a command as alias, then function, then builtin, then binary. ohmyzsh
defines `gwip` as an *alias*, which would hide our function even if we loaded
second; and `gunwipall` as a *function*, which `autoload` silently declines to
replace. Neither is a clash zsh reports. So the plugin clears both names before
claiming them, and `tests/zsh/smoke.zsh` holds a case for each.

To have all of them instead, load ohmyzsh's plugin and drop this one:

```text
ohmyzsh/ohmyzsh path:plugins/git
```

## Requirements

`git`. `gwip` also uses `grep`, and `gunwip` uses `grep` and `git rev-list`.
`gh-login` and `gh-add-key` need the GitHub CLI, at the moment you run them.

`gpsup`, `gcm` and `gmom` resolve the branch they need at the moment you run
them. `gcm` and `gmom` ask the repository what its default branch is —
`<remote>/HEAD` first, which git records at clone time from what the server
advertised, then `main`, `trunk`, `master` in that order.

## Branch commands

Two of these are not aliases. `gb` and `gbd` open a picker, and there is nothing
readable for an alias to expand to, so they are functions in both shells.

| Command | What it does |
|---|---|
| `gb [QUERY]` | Fuzzy-pick one of this repository's branches and check it out. The list is newest-commit first, search covers the name, and the preview shows the branch's recent commits |
| `gb --list [ARG…]` | Plain `git branch`, arguments passed straight through |
| `gbd [QUERY]` | Pick branches to delete — Tab marks more than one, Ctrl-A marks all |
| `gbd --force` | Skip the confirmation |

`gbd` reports every branch before it deletes anything, and says which of four
things makes the deletion safe:

| Verdict | Meaning |
|---|---|
| `merged into main` | the branch is an ancestor of the default branch |
| `squash-merged into main` | its patch is already upstream. `git branch --merged` cannot see this: a squash rewrites the commits, leaving a branch that looks exactly like one nobody merged. The tree is replayed as a single commit on the merge base and `git cherry` compares content instead of history |
| `leaves main's tree exactly as it found it` | it changes nothing that is not already there |
| `same commit as X` | another ref holds the same commit, so the commits outlive the name. A pushed branch usually lands here through its remote-tracking ref |

Anything else is `not in main`, printed in yellow, and the confirmation says how
many of those are in the set. The current branch and the default branch are
always skipped. Every deletion prints the command that puts the branch back:

```
  feat/oauth                         squash-merged into main
  feat/oauth                         deleted — restore with: git branch feat/oauth 4f2a1c0d88be
```

Deletion is `git branch -D`. `-d` refuses a squash-merged branch that is
provably redundant, and the checks above have already answered the question it
asks.
