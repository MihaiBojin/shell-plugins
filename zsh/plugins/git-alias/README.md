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
| `gb` | `git branch` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gst` | `git status` |
| `gd` | `git diff` |
| `gdca` | `git diff --cached` |
| `gcp` | `git cherry-pick` |
| `gcpc` | `git cherry-pick --continue` |
| `gcpa` | `git cherry-pick --abort` |
| `gfa` | `git fetch --all --tags --prune --jobs=10` |
| `gp` | `git push` |
| `gpsup` | `git push --set-upstream <push remote> <current branch>` |
| `gmom` | `git merge <remote>/<default branch>` |
| `gmc` | `git merge --continue` |
| `gma` | `git merge --abort` |
| `grbom` | `git rebase <remote>/<default branch>` |
| `grbc` | `git rebase --continue` |
| `grba` | `git rebase --abort` |
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
part of the package that runs at every Fish start — a run of `abbr` calls
and nothing else, about 0.2ms, no forks.

`gmom`, `grbom` and `gpsup` expand to a command substitution
(`git merge (_git_alias_remote)/(_git_alias_main_branch)`), so the repository is
asked when the line runs rather than when the shell started. `gmom` and `grbom`
expand to two, one for the remote and one for its default branch. The helpers
behind them are autoloaded functions, same names as the Zsh ones.

`gpa!` and `gcap` are the same idea twice. `gpa!` keeps going when a step
fails, which is ohmyzsh's behaviour and the reason the name is theirs; `gcap`
stops, so a rejected commit is not followed by a push.

`gh-login` and `gh-add-key` are not git. They are what a new machine needs
before git can talk to GitHub, and they are two lines, so they live here rather
than in a plugin of their own.

`!` means amend, following the convention the names come from.

The aliases are Zsh only, but the names are not. The Fish equivalent of an
alias worth having is an abbreviation, and an abbreviation has to be declared at
startup — which means `conf.d/git-alias.fish`, the one file in the package that
is not autoloaded, at 0.22ms a shell.

## Where the rest of them are

These names are ohmyzsh's, and there are about three hundred more:

**<https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git>**

That page is the reference for anything not listed above — `grbi`, `gsta`,
`glog`, and the rest. Loading both is safe. Every name this plugin defines is an
alias or an autoloaded function, and ohmyzsh's plugin defines the overlapping
ones as aliases too, so whichever loads second wins them.

To have all of them instead, load ohmyzsh's plugin and drop this one:

```text
ohmyzsh/ohmyzsh path:plugins/git
```

## Requirements

`git`. `gh-login` and `gh-add-key` need the GitHub CLI, at the moment you run
them.

`gpsup`, `gcm`, `gcm!`, `gmom` and `grbom` resolve what they need at the moment
you run them, from git's own configuration. This feature adds no settings of its
own.

**Which remote** (`_git_alias_remote`), when a repository has more than one:

1. `checkout.defaultRemote` — git's own knob for this exact ambiguity
2. `branch.<current>.remote` — every clone sets it, so it usually answers
3. `origin`, else the first remote

One remote short-circuits all of it.

**Where a push goes** (`_git_alias_push_remote`), used by `gpsup`, is a separate
question with a separate answer, and git already defines the order
(git-config(1)):

1. `branch.<current>.pushRemote`
2. `remote.pushDefault`
3. the remote above, single-remote repositories included

That order is git's, not this plugin's. It exists so "pull from upstream, push
to my fork" works, which is also why neither key resolves the *base*: they say
where commits go, not where they come from.

**Which branch** (`_git_alias_main_branch`): that remote's own
`refs/remotes/<remote>/HEAD`, which git records at clone time from what the
server advertised, then any other remote's, then `main`, `trunk`, `master`.
Every remote carries a default of its own, and they differ — a fork's `origin`
can say `main` while its `upstream` says `develop`.

`gmom` and `grbom` name that remote rather than a literal `origin`, so a fork
checkout replays onto the remote it belongs to. The names are ohmyzsh's, where
the `om` is `origin` and nothing else.

## Commands that say what they are about to run

`gcm`, `gcm!` and `gup` are functions in both shells rather than an alias and an
abbreviation. Both of those expand to a fixed string, and the default branch is
not one: `git checkout (_git_alias_main_branch)` is what you could read before
pressing Return, and the branch it reached was only visible afterwards.

Each prints the command it is about to run on stderr first, with the branch
filled in, dimmed when stderr is a terminal and plain when it is redirected.
stderr keeps them pipeable.

| Command | What it does |
|---|---|
| `gcm [ARGS...]` | Check out the default branch. Arguments follow the branch name |
| `gup [ARGS...]` | `git fetch --all --tags --prune --jobs=10`, then `git pull --rebase`. Arguments go to the pull |
| `gcm!` | Both, in order, stopping at the first failure. Takes no arguments |

`gcm!` writes the git commands out rather than calling `gcm` and `gup`, so the
line it prints is exactly what runs and one file answers what it does.

## Branch commands

Neither of these is an alias, so both are functions in both shells: a picker
has nothing readable for an alias to expand to.

`gb` itself is `git branch`, so `gb -d name`, `gb -a` and every other flag reach
git untouched. The picker is `gb!`, which is the convention the `!` names follow
here: the plain name is git's, the banged one is ours.

| Command | What it does |
|---|---|
| `gb! [QUERY]` | Fuzzy-pick one of this repository's branches and check it out. The list is newest-commit first, search covers the name, and the preview shows the branch's recent commits |
| `gbd! [QUERY]` | Pick branches to delete — Tab marks more than one, Ctrl-A marks all |
| `gbd! --force` | Skip the confirmation |

`gbd!` reports every branch before it deletes anything, and says which of four
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
