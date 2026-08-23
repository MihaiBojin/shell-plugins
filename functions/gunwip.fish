function gunwip --description 'Undo the last commit if it is a work in progress'
    # The subject alone, so a `--wip--` mentioned in a commit body or in a diff
    # cannot be mistaken for one. gunwipall does the same for a whole run.
    set -l subject (git log --max-count=1 --format=%s 2>/dev/null)
    if string match --quiet -- '*--wip--*' "$subject"
        git reset HEAD~1
    end
end
