function gwip --description 'Commit everything as a work in progress'
    # --no-gpg-sign because a commit that exists to be thrown away should not
    # stop to ask for a passphrase, and [skip ci] because it is not worth a
    # build. gunwip takes the last one back; gunwipall takes a whole run.
    git add -A

    # Only when there is something to remove: `git rm` with no pathspec is a
    # fatal error, and hiding it behind 2>/dev/null hides real ones too.
    set -l deleted (git ls-files --deleted)
    if test (count $deleted) -gt 0
        git rm --quiet $deleted
    end

    git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"
end
