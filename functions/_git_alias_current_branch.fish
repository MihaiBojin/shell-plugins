function _git_alias_current_branch -d 'The branch checked out here, or nothing on a detached HEAD'
    # Used by gpsup, which needs a name to push under.
    git symbolic-ref --quiet --short HEAD 2>/dev/null
end
