# git-alias — the short git and GitHub CLI commands, as Fish abbreviations.
#
# conf.d rather than functions/, because an abbreviation has to be declared at
# startup to exist: declared inside an autoloaded function file it only appears
# once something else has caused that file to load, which is a rule nobody can
# keep in their head. This is the one thing in this package that runs at every
# Fish start, and it is twenty-nine builtin calls: 0.22ms, measured, no forks.
#
# Abbreviations rather than functions, because expansion is the point: what runs
# is what you can see on the line before you press Return, and it lands in
# history spelled out. That is also what makes `gca!` safe to have.
#
# The four that have to ask the repository something expand to a command
# substitution, so the question is asked when the line runs rather than when the
# shell started. gmom and grbom ask twice: which remote, then what that remote
# calls its default branch.
#
# Not here: gb! and gbd!, which open a picker — an abbreviation expands to text
# you can read before it runs, and there is nothing readable to expand a picker
# to.

if status is-interactive
    # Add, commit, amend
    abbr --add ga -- 'git add'
    abbr --add gaa -- 'git add --all'
    abbr --add gc -- 'git commit --verbose'
    abbr --add gca -- 'git commit --verbose --all'
    abbr --add 'gca!' -- 'git commit --verbose --all --amend'
    abbr --add 'gcan!' -- 'git commit --verbose --all --no-edit --amend'

    # Move about. gcm goes to whatever this repository calls its default
    # branch, asked at the moment you run it rather than guessed.
    abbr --add gb -- 'git branch'
    abbr --add gco -- 'git checkout'
    abbr --add gcb -- 'git checkout -b'
    abbr --add gcm -- 'git checkout (_git_alias_main_branch)'
    abbr --add gst -- 'git status'

    # Look
    abbr --add gd -- 'git diff'
    abbr --add gdca -- 'git diff --cached'

    # Cherry-pick, and the two ways out of one
    abbr --add gcp -- 'git cherry-pick'
    abbr --add gcpc -- 'git cherry-pick --continue'
    abbr --add gcpa -- 'git cherry-pick --abort'

    # Push. gpsup is the first push of a new branch; the rest is the usual one.
    # Its remote is remote.pushDefault when set — what makes a fork checkout
    # work: branch from upstream, push to the fork.
    abbr --add gp -- 'git push'
    abbr --add gpsup -- 'git push --set-upstream (_git_alias_push_remote) (_git_alias_current_branch)'

    # Fetch. --prune is explicit rather than left to fetch.prune, so the
    # abbreviation means the same thing wherever it is typed.
    abbr --add gfa -- 'git fetch --all --tags --prune --jobs=10'

    # Catch this branch up with the default branch, whatever it is called here
    # and wherever this repository's remote is: merge it in, or replay onto it.
    # Either can stop on a conflict, so either has a --continue and an --abort.
    abbr --add gmom -- 'git merge (_git_alias_remote)/(_git_alias_main_branch)'
    abbr --add gmc -- 'git merge --continue'
    abbr --add gma -- 'git merge --abort'
    abbr --add grbom -- 'git rebase (_git_alias_remote)/(_git_alias_main_branch)'
    abbr --add grbc -- 'git rebase --continue'
    abbr --add grba -- 'git rebase --abort'

    # Everything, in one go, for a repository nobody else reads. gcap stops at
    # the first failure; gpa! does not, so a rejected commit still pushes.
    abbr --add 'gpa!' -- 'git add -A; git commit --message "save all"; git push; git status'
    abbr --add gcap -- 'git add -A && git commit --message "CommitAndPush" && git push && git status'

    # GitHub CLI. Not git, but the same two commands every new machine needs
    # before git works with GitHub at all, so they live here rather than in a
    # feature of their own.
    abbr --add gh-login -- 'gh auth login -p ssh -h github.com --skip-ssh-key -s \'repo,admin:public_key,write:org\''
    abbr --add gh-add-key -- 'gh ssh-key add "$HOME"/.ssh/id_ed25519.pub --type authentication'
end
