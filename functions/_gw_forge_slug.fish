function _gw_forge_slug -a repo -d 'OWNER/NAME for the forge CLI'
    test -n "$repo"; or set repo $PWD
    set -l remote (_gw_remote $repo); or return 1
    set -l url (git -C $repo remote get-url $remote 2>/dev/null); or return 1
    # git@host:owner/name.git and https://host/owner/name.git both reduce to the
    # last two path components without their .git.
    set -l path (string replace -r '^[^:]+://[^/]+/' '' -- (string replace -r '^[^@]+@[^:]+:' '' -- $url))
    string replace -r '\.git$' '' -- $path
end
