# git-worktree

Three commands for working with git worktrees, plus a help command.
Every worktree sits beside the repository it belongs to:

```
<PARENT>/.worktrees/<NAME>/<REPO>
```

`<PARENT>` is the directory holding the main checkout, and nothing configures
that — the companion `origin` plugin derives the same path the same way, so two
tools cannot disagree about a location neither of them can be told. So:

| Repository | `gwa auth` creates |
|------------|--------------------|
| `~/git/MihaiBojin/webapp` | `~/git/MihaiBojin/.worktrees/auth/webapp` |
| `~/dotfiles` | `~/.worktrees/auth/dotfiles` |

Several repositories under one parent therefore share a directory, one `<REPO>`
subdirectory each — `.worktrees/auth/{webapp,api}` — so the same `NAME` used in
each of them groups their worktrees together. That is the shape
[multirepo](https://github.com/releasetools/multirepo) uses under its own root,
`.multirepo/<name>/<repo>`, for the different job of driving one feature across
several repositories at once. This plugin does one repository at a time, and
`NAME` is just a branch: `.worktrees/auth/` holds three independent worktrees,
not one thing in three parts, and `gwr` removes exactly the one it was asked
about.

`<NAME>` is the branch, unprefixed and unaltered: `gwa auth` creates branch
`auth`, and `gwa fix/login` nests as `.worktrees/fix/login/<REPO>`. Directory
name equals branch name is the invariant every tool writing into this root
keeps; whether to put a slash in a branch name is your decision, not something
to flatten away.

Nesting does mean one branch's worktree can be another branch's parent
directory: branch `fix` in a repository called `login` occupies
`.worktrees/fix/login`, and so does branch `fix/login`. Neither can have it, so
`gwa` [refuses both directions](#when-two-branches-want-the-same-directory).

The path is derived from the **main checkout**, so it is the same whether you
run a command from the repository or from inside one of its worktrees.

`gwl` and `gwr --all` operate on the repository you are standing in, and error
out when there isn't one; there is no cross-repository listing. `gwr` given an
explicit path works on whichever repository that path belongs to, and asks
every question — which remote, which head branch, is this branch finished — of
*that* repository rather than of the shell's.

Fish has the same four commands, in `functions/gw{,h,l,a,r}.fish` at the top of
this repository — see [The Fish commands](#the-fish-commands) for what differs.

## Commands

| Command | What it does |
|---------|--------------|
| `gw`, `gwh` | Print the help below, including where *this* repo's worktrees would go |
| `gwl [QUERY]` | Pick one of this repository's worktrees with fzf and `cd` into it |
| `gwl --list` | Print them instead: mark, branch, path, tab-separated |
| `gwa NAME [BASE]` | Create a worktree on branch `NAME`, based on `BASE`, and `cd` into it |
| `gwa` | Pick a branch to make one for — including one that only exists on the remote |
| `gwr [PATH\|QUERY]` | Remove a worktree whose branch is finished, and the branch with it |
| `gwr --all [--yes]` | The same, to every finished worktree at once |
| `gwm NEW` | Rename this worktree's branch to `NEW` and move its checkout to match |

### `gw` / `gwh` — help

```
gw — git worktree helpers

  gwl [QUERY]              pick one of this repository's worktrees and cd into it
      -l, --list           print them instead, one per line: mark, branch, path
  gwa [NAME] [BASE]        add a worktree for branch NAME (based on BASE), and cd into it
      (no NAME)            pick a branch, or type a new name, with fzf
      --fetch              ask the remote whether NAME exists there already (the default)
      --no-fetch           stay offline
  gwm NEW                  rename this worktree's branch to NEW and move it to match
  gwr [PATH|QUERY]         remove a worktree whose branch is finished, and the branch
      -f, --force          remove it even when it is not; the branch is kept
      --no-forge           decide from git alone; never ask GitHub/GitLab
      --all                do it to every finished worktree; a dry run without --yes
        -y, --yes          go through with it
        -n, --dry-run      say what would go and stop; wins over --yes
        --branch NAME      consider only this branch
        --fetch            refresh the head branch first (the default)
        --no-fetch         decide offline: no fetch, and no forge either
  gw,  gwh                 this help

worktrees live beside their repository, at
  <PARENT>/.worktrees/<NAME>/<REPO>
  here   ~/git/MihaiBojin/.worktrees/NAME/webapp

details: ~/…/shell-plugins/zsh/plugins/git-worktree/README.md
```

The `here` line resolves the destination the same way `gwa` would, so it shows
where a worktree would actually land; outside a repository it says so instead.
The `details:` line points at wherever your plugin manager put this checkout.
`gw` prints to stdout so it can be piped; the `-h` flag on the individual
commands prints the same text to stderr.

### `gwl` — list and jump

```zsh
gwl              # fuzzy-pick from this repository's worktrees
gwl fix          # same, with the picker pre-filtered
```

The list is `git worktree list` for the repository you are standing in — its
worktrees plus its main checkout, marked `*` when you are in it. Nothing from
other repositories ever appears, even the sibling repos sharing the same
directory, and there is no filesystem scanning at all: git already
knows where this repository's worktrees are, wherever they sit. That also means
worktrees created before this layout existed keep showing up. Outside a
repository there is nothing to list, so it errors.

Fuzzy search covers the branch column; the path is shown but
deliberately not searched, since fuzzy-matching a long absolute path makes every
entry match everything. The preview pane shows `git status` and the last
commits.

With a `QUERY` that narrows to a single worktree, fzf selects it without asking.
Without fzf installed — or with stdin redirected, where fzf would draw its
full-screen interface over the terminal and wait for a key that cannot arrive —
the picker degrades to a numbered list.

### `gwa` — add

```zsh
gwa fix-login              # branch off the repo's default branch
gwa fix-login release/2.x  # branch off something else
gwa feature/oauth          # slashes are fine: .../oauth nests under .../feature
gwa --fetch their-branch   # check the remote for the name, whatever the config says
gwa --no-fetch fix-login   # stay offline
```

`NAME` becomes both the new branch and the directory, spelled the same way.

With no `NAME`, fzf offers every branch: the local ones, marked where they
already have a worktree, and the remote's branches that have no local
counterpart. That last set is the one `gwl` can never show you, because `gwl`
lists worktrees and these are the branches without one. Typing a name that
matches nothing and pressing enter creates it, exactly as `gwa NAME` would.
Without fzf, or without a terminal on stdin, there is no list worth printing —
every branch in the repository, unfiltered — so it asks for a `NAME` instead.
`BASE` defaults to the repository's default branch (see below). Flags may go
anywhere in the arguments.

A few things it does on your behalf:

- Prefers the remote-tracking ref (`origin/main` over `main`) and fetches that
  one branch first, so new branches start from what the remote actually has.
- Creates new branches with `--no-track`, so `git push` can't accidentally
  target the base branch. Tip: set `push.autoSetupRemote = true` in your git
  config if you want the first `git push` to just work.
- If `NAME` already exists on the remote, checks it out with tracking instead of
  branching off `BASE`.
- If `NAME` is already checked out somewhere, `cd`s there instead of failing.

#### When two branches want the same directory

Because the directory is the branch name, one branch's worktree can be the
place another branch's worktrees go — with no second tool involved. Two
repositories under one parent, branch `fix` in the one called `login`: that
occupies `<root>/fix/login`, and `gwa fix/login` from its sibling wants the
same directory as the parent of `<root>/fix/login/<REPO>`.

`gwa` refuses both directions, and names what is in the way:

```
gw: <root>/fix/login is a worktree of ~/git/Org/login — 'fix/login' would nest inside it
gw: pick a branch name that is not a prefix of it, or move that worktree
```

```
gw: <root>/fix/login already exists and is not empty — another branch is nesting under it
```

When the thing in the way is one of *this* repository's worktrees it names the
branch instead: `is this repository's worktree for 'a'`.

Worth catching rather than leaving to git, which reports the first as a bare
"already exists" and does not fail on the second at all — it goes ahead and
creates a worktree inside the directory holding another branch's. A later
`git clean -xdff` in the outer checkout then deletes the inner one's files and
leaves the other repository's administrative half behind as prunable.

A third question of the same kind is asked before either: does this directory
belong to *this* repository at all? With the root derived from the checkout's
own parent, two repositories cannot normally reach one path — but a worktree
made by hand, or a repository that has moved, can already be sitting there.
`git worktree list` cannot answer, because the squatter is another
repository's worktree and this one has never heard of it, so git is asked
directly:

```
gw: <root>/auth/demo is a worktree of ~/other/demo, not of this repository
gw: move it, or pick a name that does not collide with it
```

Without it the failure is silent: `gwa` reported "worktree already exists",
exited 0, and put you inside the other repository's checkout.

All three are the same question in three positions — is this directory
already spoken for, and by whom — and none of them can be answered from
`git worktree list`:

| | Where | Why the list cannot answer |
|---|---|---|
| the path itself is a worktree | `<root>/<NAME>/<REPO>` | a squatter belongs to another repository, so this one has never heard of it |
| an ancestor is a worktree | `<root>/<NAME>` and above | same |
| the path is a non-empty directory | `<root>/<NAME>/<REPO>` | no repository owns it yet; another branch nests under it |

`git rev-parse --git-common-dir` from inside the candidate is what answers the
first two, in `_gw_owns`.

### Progress

Anything that can block — a fetch, an `ls-remote`, checking out a large tree —
runs behind a spinner, so a slow network looks like work rather than a hang:

```
[⠹] fetching origin/main
[✓] fetching origin/main
[⠴] asking origin about 'fix-login'
[✓] asking origin about 'fix-login'
[⠧] creating 'fix-login' from origin/main
[✓] creating 'fix-login' from origin/main
```

The command's own output is captured and shown **only if it fails**, indented
under a red `[✗]`, so git's chatter stays out of the way until it matters. The
exit status is always passed through untouched.

If a step runs past ten seconds the line gains `(still waiting — ^C to cancel)`.
That is mostly there for the case git decides to ask for an SSH passphrase or
HTTPS credentials: its prompt gets captured along with everything else, so
without the hint an invisible question looks identical to a stalled network.
`^C` cancels the underlying command and restores the cursor.

Nothing animates when stderr isn't a terminal — piped or scripted runs get just
the one result line per step.

### How much it talks to the remote

| Mode | What happens |
|------|--------------|
| `--no-fetch`, `zstyle ':git-worktree:' fetch no`, or `git config git-worktree-plugin.fetch no` | Nothing. Everything resolves from local refs. |
| `zstyle ':git-worktree:' fetch yes` | Fetches the single base branch (`git fetch origin main`), best-effort: a failure warns and falls back to your local copy. |
| default, or `--fetch` | The above, plus one `git ls-remote` to check whether `NAME` itself exists on the remote. |

If a colleague pushed `their-branch` since your last fetch, `gwa their-branch`
finds it and checks it out tracking `origin/their-branch`. The `ls-remote` that
answers costs one ref-advertisement round trip, filtered server-side under
protocol v2, so it stays cheap on a repository with many refs. `fetch yes`
declines it, at the price of forking a *second, divergent* branch of that name
off the base whenever the remote already had one.

Nothing here runs at shell startup. The network is only ever touched by an
explicit `gwa`.

### Which remote

`origin` is a convention, not a fact — a repo can have one remote called
something else, or several with no obvious winner. So the remote is resolved by
asking the repository, in decreasing order of how deliberate the answer is:

1. `zstyle ':git-worktree:' remote <name>`
2. `git config git-worktree-plugin.remote` — per-repo, written by the prompt below
3. `git config checkout.defaultRemote` — git's own knob for this exact ambiguity
4. `git config remote.pushDefault`
5. `branch.<current>.remote` — last, because every clone sets it automatically:
   it says where the current branch came from, not which remote the repository
   belongs to
6. **Exactly one remote** → that one, whatever it is named
7. Otherwise `gwa` **asks**, and remembers the answer in `git-worktree-plugin.remote`:

```
gw: 3 remotes and nothing says which one — pick:
   1) origin    git@github.com:me/repo.git
   2) upstream  git@github.com:them/repo.git
   3) mirror    git@git.example.com:mirror/repo.git
Choice [1]:
```

Read-only commands (`gwl`, `gwr`, and the listing) never prompt — they fall back
to `origin`, else the first remote, so a picker can't be interrupted by a
question. The remote decides where branches come from, not where worktrees go —
the path comes from the checkout's own location.

### Finding the default branch

`BASE` defaults to whatever the repository itself says its default branch is:

0. **`git config git-worktree-plugin.headBranch`** — an answer somebody wrote
   down beats anything derived.
1. **`refs/remotes/<remote>/HEAD`** — git records this at clone time from what
   the server advertises. This is the real answer, and it is what distinguishes
   `master` from `main` without guessing: a clone of a `master`-default repo
   that also has a `main` branch still resolves to `<remote>/master`. Ignored if
   it dangles, which is what a server-side rename leaves behind.
2. **`git remote set-head <remote> --auto`** — re-asks the server and caches the
   result, for when the symref is missing (the remote was added by hand rather
   than cloned) or stale. Skipped under `--no-fetch`.
3. **Exactly one of `main`, `master`, `trunk`** exists → that one.
4. Otherwise `gwa` **asks**, listing those plus the 25 most recently updated
   branches, and records your answer with `git symbolic-ref
   refs/remotes/<remote>/HEAD` — so git and every other tool benefit, and
   nothing asks again.

Called non-interactively it warns, guesses, and tells you to run `git remote
set-head <remote> --auto` rather than silently picking one.

### `gwm` — rename

```zsh
gwm renamed/thing       # from inside the worktree you want renamed
gwm shorter-name
```

Directory name equals branch name is the invariant every tool writing into this
root keeps, so renaming a branch is two operations that have to happen together:
`git branch -m`, and `git worktree move` to the directory the new name asks for.
Doing one without the other leaves a worktree whose directory says one thing and
whose HEAD says another — which is the state `gwl` and `gwr` both read wrong.

It acts on the worktree you are standing in. From the main checkout there is
nothing to rename, so it opens the picker instead. Three pieces of tidying git
does not do on its own come with it: the new parent is created first, because
`git worktree move` will not create nested parents; the directories the old name
leaves empty are removed, up to and including the root; and the shell follows
the worktree if that is where it was.

It refuses a locked worktree, a detached one, the main checkout, a name that is
already this branch's, a name another branch already has, and a destination
another repository's worktree is nesting above — the same collision `gwa`
refuses, for the same reason.

The branch is renamed before the move. If the move then fails, the message says
so and prints the `git worktree move` that finishes the job.

### `gwr` — remove one

```zsh
gwr                        # pick one of this repo's, confirm, remove
gwr fix-login              # a query, if it isn't an existing path
gwr ~/.worktrees/fix-login/repo
gwr --force <path>         # remove it even when it is not finished
```

One worktree you named, or with `--all` every one that qualifies: same
predicate, same refusals either way.

| State | Worktree | Branch |
|---|---|---|
| finished (any of the three checks) | removed | **deleted** |
| not finished | **refused**, with the reason | untouched |
| not finished, `--force` | removed | kept |
| uncommitted changes or a parked stash | **refused** | untouched |
| the same, `--force` | removed | kept |
| locked | **refused** | untouched |

A branch that is not safe to delete is work in progress, and its checkout is
where that work lives — so an unfinished worktree is refused outright rather
than removed with its branch left behind:

```
gw: not removing ~/git/Org/.worktrees/wip-thing/repo
  branch wip-thing — not merged into main
  the checkout is where unfinished work lives; remove it anyway with:
    gwr --force ~/git/Org/.worktrees/wip-thing/repo   (the branch is kept)
```

A finished one says what will happen before it asks:

```
Remove worktree ~/git/Org/.worktrees/fix-login/repo
  branch fix-login — squash-merged into main; it will be deleted
Proceed? [y/N] y
[✓] removing repo
gw: deleted branch fix-login (squash-merged into main)
```

**`--force` never deletes a branch**, here or in `gwr --all`. It overrides the
refusal to remove a *checkout*, which is recoverable — the branch still exists
and `gwa NAME` brings the worktree back.

Two exceptions, both about there being nothing to recover from:

A **detached** worktree has no branch to survive it, so `--force` names the
commit instead, before and after:

```
gw: nothing will refer to c51b049 afterwards; keep it first with:
      git -C ~/git/Org/repo branch NAME c51b049…
```

A worktree holding **submodules** is refused outright. `git worktree remove
--force` walks past git's own refusal and deletes `.git/worktrees/<id>/modules/`
with the checkout — the submodule's only copy of anything committed there, which
nothing brings back and `git fsck` does not notice. If you mean it, the raw
`git worktree remove --force` is printed for you to run deliberately. Deleting a branch stays automatic and
happens only when the predicate proved it merged. `git branch -d` refuses a
squash-merged branch, because from where git stands it is unmerged; `-D` is
used only after check 2 has proved otherwise, never as a fallback for a branch
that failed the checks.

There is no flag that keeps a finished branch. The escape hatch is recovery
instead, printed for every branch either command deletes:

```
gw: deleted branch fix-login (was a1b2c3d) — squash-merged into main
    restore: git branch fix-login a1b2c3d
```

One line per branch rather than one per run, so any single deletion can be
undone on its own with one paste. The sha is read before the delete, since
afterwards there is no name left to resolve it from.

Two things `--force` does not cover. A **locked** worktree: you locked it
deliberately, and git itself wants `--force` twice, so unlock it and mean it.
And the **head branch**: a worktree can have `main` checked out, and `main` is
an ancestor of `origin/main`, so it passes check 1 — the checkout goes, the
branch never does.

It refuses to remove the main worktree, steps out of the worktree first if you
are inside it, and tidies up the directories it leaves empty — `.worktrees`
included, once the last worktree under it is gone. After running, it checks
whether `git worktree prune` would still find stale metadata and tells you if
so.

Resolving the head branch is offline and never interactive here — `gwr` will
not stop to ask which remote it is on while it is already asking whether to
proceed. If it cannot work one out, the worktree is refused and it says so. The
forge check does reach the network; `--no-forge`, or
`zstyle ':git-worktree:' forge no`, turns it off.

### `gwr --all` — sweep up what is finished

```zsh
gwr --all                      # say what would go, and what would not, and why
gwr --all --yes                # go through with it
gwr --all --branch fix-login   # consider that one branch and no other
gwr --all --no-forge           # decide from git alone, but still refresh the head branch
gwr --all --no-fetch           # touch nothing at all: no fetch, and no forge either
```

Same predicate and same refusals as a plain `gwr`; the difference is that
nothing stops to ask about each worktree. So it does nothing until asked twice:
the plain run is a dry run, and the dry run is the confirmation.

```
  skip         main — is the worktree you are standing in
  skip         dirty — has uncommitted changes
  would remove ordinary — merged into main
  would remove squashed — squash-merged into main
  skip         unmerged — not merged into main
gw: 2 to remove, 3 left alone — re-run with --yes to do it
```

Every line has a reason, including the ones that stay.

#### What counts as finished

Three checks, in order. Any one of them qualifies a branch:

1. **git can see the merge** — `git merge-base --is-ancestor`. The ordinary case.
2. **The change is already upstream, though git cannot see it.** A squash
   rewrites a branch's commits into one, so git sees a branch whose commits
   appear nowhere in the head branch — the same shape as a branch nobody ever
   merged. Reaping on that reading loses work; refusing on it means never
   reaping anything. So the question changes: replay the branch's tree as a
   single commit on the merge base, and let `git cherry` say whether that patch
   is upstream. It compares content, which is what a squash preserves. A branch
   whose tree already *is* the head branch's tree short-circuits to yes.
3. **The forge says so** — a pull or merge request in state `MERGED` or
   `CLOSED`. One `gh`/`glab` call for the whole repository, never one per
   branch, and skipped entirely without the CLI, without authentication, or
   under `--no-forge`. A branch qualified only this way is still kept if it has
   commits its upstream has not got — a merged request says nothing about work
   pushed after it — or if it has no upstream at all, which is the normal state
   for a branch `gwa` made, since those are created with `--no-track`.

Everything but the third works offline. Nothing here asks a language model
anything — the judgement is these three checks and the refusals below.

#### What it refuses

Skipped, with the reason printed, and never worked around:

| Refusal | Why |
|---|---|
| the worktree you are standing in | removing the ground under your feet |
| the main worktree | it is the repository |
| a detached HEAD | there is no branch to be finished |
| the head branch itself | `main` is not rubbish |
| a locked worktree | you locked it on purpose |
| uncommitted changes | including a file you never `git add`ed |
| a stash parked on the branch | `git stash list` still names it |
| unpushed commits, when only the forge qualified it | see check 3 |
| no upstream at all, when only the forge qualified it | a request cannot speak for commits nothing was pushed to |

The uncommitted check is `git status --porcelain`, which counts untracked
files and ignores gitignored ones — exactly the set that makes `git worktree
remove` refuse. So there is no `--force` for the removal itself, and a file you
forgot to add protects the whole worktree. `gwr --force` is the deliberate way
past that.

#### Deleting the branch

`--all` takes no `--force`: it never removes a checkout that is not finished, and
deleting a branch it *has* proved finished needs no permission beyond the
`--yes` that started the run. `git branch -d` refuses a squash-merged branch,
so `-D` follows it — reached only after check 2 proved the change is upstream,
never for a branch that failed the checks.

Every deletion prints the command that puts the branch back:

```
[✓] removing fix-login — squash-merged into main
gw: deleted branch fix-login (was a1b2c3d)
    restore: git branch fix-login a1b2c3d
```

## The Fish commands

`gw`, `gwl`, `gwa` and `gwr` exist in Fish too, as autoloaded functions in this
repository's top-level `functions/` directory, where Fisher installs them. Same
layout, same commands, same three checks for what counts as finished, same
refusals, and the same per-repository git config keys — so the two shells agree
about a repository without either of them writing anything the other reads.

It is a reimplementation, not a translation, and a little smaller: 1832 lines
across 37 files against 2090 across 46. What is left differs in three places,
and each is a deliberate omission rather than an oversight.

| Zsh | Fish | Why |
|---|---|---|
| asks which remote when several are plausible, and remembers the answer | resolves the same ladder, falls back to `origin` and then to the first remote | a picker that stops to ask a second question is worse than a wrong default you can override with one config key |
| asks which branch is the head branch, listing 25, and records the answer | climbs the same ladder and warns when the answer it reached was a guess | the same reason; only when the ladder runs out does it give up and print `git remote set-head <remote> --auto` |
| `zstyle ':git-worktree:' …` | `set -g git_worktree_…` | Fish has no zstyle, and a global variable is what its own configuration looks like |

Both shells run anything that can reach the network behind a spinner, and both
capture its output and show it only on failure.

Fish gets the same completions, in the repository-root `completions/` that
Fisher installs: branch names where a branch is wanted, this repository's
worktree paths for `gwr`, and nothing where the argument is a name that does
not exist yet. Fish autoloads one the first time you press Tab on that command,
so they cost nothing at startup.

Configuration, then, is three variables and the same two git config keys:

```fish
set -g git_worktree_fetch no       # never touch the network (default: yes)
set -g git_worktree_fetch always   # always check NAME on the remote, as if --fetch
set -g git_worktree_remote upstream
set -g git_worktree_forge no       # decide from git alone, never ask GitHub/GitLab
```

The forge check needs `gh`, or `glab` **and** `jq` — `gh` embeds its own jq and
`glab` does not, so the GitLab half is skipped rather than parsed by hand.

`fish --no-config tests/fish/git-worktree.fish` runs against real repositories,
on a fixture with one worktree per way a branch can be unfinished — the same
shape the Zsh suite builds, so the two can be read line for line. It covers the
layout, both collision refusals, all three finished-checks including the forge,
every refusal (standing-in, main, detached, dirty, untracked, stashed, locked,
submodule), `gwm`, `--force`, the sweep's fetch, both halves of `gwr --all`, the
completions, and the two git config keys.

## Configuration

Add to `.zshrc` before the plugin loads (all styles are read at call time):

```zsh
zstyle ':git-worktree:' fetch no                 # never touch the network
zstyle ':git-worktree:' fetch yes                # base branch only; do not check NAME on the remote
zstyle ':git-worktree:' remote upstream          # force a remote (default: resolved per repo, see above)
zstyle ':git-worktree:' spinner ascii            # |/-\ instead of braille (default: braille in a UTF-8 locale)
zstyle ':git-worktree:' spinner no               # result lines only, no animation
```

`gwa --fetch` / `--no-fetch` override the `fetch` style for a single call.

The network policy is also readable from git config, which is how the Fish
plugin and the companion `origin` CLI see the same answer:

```zsh
git config git-worktree-plugin.fetch no          # this repository stays offline
```

The style wins where both are set, because it is how a preference is stated for
every repository at once. The default, with neither set, is `always`.

Per-repository, in git config rather than zstyle:

```zsh
git config git-worktree-plugin.remote upstream   # which remote this repo belongs to
git config --unset git-worktree-plugin.remote    # forget it and ask again
git config git-worktree-plugin.headBranch main   # override the default-branch resolution
git remote set-head origin --auto                # (re)record the default branch
```

### Shared with the `origin` plugin

Both keys live in the `git-worktree-plugin.*` namespace, which is nobody
else's: the companion [`origin`](https://github.com/MihaiBojin/agent-plugins)
plugin reads exactly the same two, so a repository answers "which remote" and
"which head branch" once, for both tools. That is the entire configuration
surface across them.

| Key | Meaning |
|---|---|
| `git-worktree-plugin.remote` | Which remote this repository belongs to |
| `git-worktree-plugin.headBranch` | Override the default-branch resolution |

Where worktrees go is deliberately not on that list. `.worktrees` beside the
main checkout is derived by both tools from the repository's own location, so
there is nothing to keep in step and nothing to set on a new machine.

An earlier version of this plugin wrote `gw.remote`. That key is no longer read
at all. If a repository has one:

```zsh
git config --rename-section gw git-worktree-plugin
```

Nothing here changes where worktrees are created; `gwl` finds them through git
wherever they sit, including any left over from an older layout.

## Completion

The plugin puts `completions/` on `$fpath` and does **not** run `compinit` —
that belongs to the consuming configuration, which must run it once, after all
plugins have loaded. `gwa` then completes branch names for `BASE`, and `gwr`
completes worktree paths.

If your configuration still runs `compinit` *before* loading plugins, the plugin
notices (`compdef` already exists) and registers the three completions directly,
so they work either way.

## If the parent is inside another repository

`.worktrees/` beside your repo is untracked junk if that parent directory
happens to sit inside another working tree. `gwa` checks for this the first time
it creates the directory and tells you to gitignore it. Worth doing: a plain
`git clean -xdf` will skip a worktree (git refuses to delete a directory
containing a `.git`), but `git clean -xdff` deletes it and leaves the branch's
admin half behind as prunable.

## Moving things

Git records **absolute** paths in both halves of a worktree link — the `.git`
file in the checkout and `.git/worktrees/<name>/gitdir` in the repo. Moving
either end breaks it; `git worktree repair <path>...` from the main checkout
fixes the pointers. Use `git worktree move` rather than `mv` to relocate one,
which is also how to migrate worktrees created under an older layout.

## Requirements

- `git`, plus `mkdir`, `mktemp`, `rm` and `rmdir` — all POSIX, all already on
  any machine that has git. Verified: the whole `gwa` → `gwl` → `gwr` cycle
  runs with nothing else on `$PATH`.
- `fzf` is optional. Without it the pickers fall back to numbered lists.
- `gh` or `glab` is optional, and only `gwr --all` and `gwr` use it. Without one,
  both fall back to the two checks that need no network.
- `sleep` only if `zsh/zselect` is unavailable, which it normally is not.
- No platform assumptions — nothing here is macOS- or Homebrew-specific.

## Notes

- The names don't clash with ohmyzsh's git plugin, which uses `gwt`, `gwta`,
  `gwtls`, `gwtmv` and `gwtrm`.
- Every command and helper is an autoloaded file under `functions/`. Loading the
  plugin defines no function bodies and forks nothing; the first `gw*` you type
  is what reads them.
- Listing is fork-free: branches are read straight out of each worktree's
  `HEAD`, so `gwl` stays fast with many worktrees.
