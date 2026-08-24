# git-alias

The short git commands, defined here so the collection stands on its own, plus
two `gh` ones.

| Alias | Runs |
|---|---|
| `ga` | `git add` |
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

The aliases are Zsh only. The Fish equivalent of an alias worth having is an
abbreviation, and abbreviations have to be declared at startup, which means
`conf.d/` — and that stays empty.

## Where the rest of them are

These names are ohmyzsh's, and there are about three hundred more:

**<https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git>**

That page is the reference for anything not listed above — `grbi`, `gsta`,
`glog`, and the rest. Nothing here conflicts with it: the definitions
are the same, so loading both changes nothing except which one wins.

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
