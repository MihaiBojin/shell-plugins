function _gw_forge_state -a branch repo -d 'What the forge says about the request for $branch'
    # One call for the whole repository, cached for the rest of this shell's
    # command, never one call per branch. Leaves `<state>\t<number>` in
    # $_gw_reply. State is whatever the forge says: MERGED, CLOSED, OPEN.
    #
    # gh embeds its own jq, so it needs nothing else. glab does not, so the
    # GitLab half is skipped when jq is missing rather than parsed by hand.
    test -n "$repo"; or set repo $PWD
    set -g _gw_reply ''

    set -l key (path resolve $repo)
    if not set -q _gw_forge_cache_key; or test "$_gw_forge_cache_key" != "$key"
        set -g _gw_forge_cache_key $key
        set -g _gw_forge_cache
        set -g _gw_forge_noun request

        # Fail closed. Without -R, gh and glab answer about whatever repository
        # the shell happens to be standing in, and for `gwr <path>` that is
        # somebody else's — an answer that then decides whether to delete a
        # branch. No forge data at all is strictly better than another
        # repository's. `string collect` because an empty substitution drops
        # the argument entirely, which would leave `gh -R pr list`.
        set -l slug (_gw_forge_slug $repo | string collect)
        if test -n "$slug"
            if command -q gh; and git -C $repo remote -v 2>/dev/null | string match --quiet '*github.com*'
                set -g _gw_forge_noun 'pull request'
                set -g _gw_forge_cache (gh -R $slug pr list --state all --limit 200 \
                    --json headRefName,state,number \
                    --jq '.[] | "\(.headRefName)\t\(.state)\t\(.number)"' 2>/dev/null)
            else if command -q glab; and command -q jq; and git -C $repo remote -v 2>/dev/null | string match --quiet '*gitlab*'
                set -g _gw_forge_noun 'merge request'
                set -g _gw_forge_cache (glab -R $slug mr list --all --output json 2>/dev/null |
                    jq -r '.[] | "\(.source_branch)\t\(.state | ascii_upcase)\t\(.iid)"' 2>/dev/null)
            end
        end
    end

    for line in $_gw_forge_cache
        set -l fields (string split \t -- $line)
        test (count $fields) -ge 3; or continue
        test "$fields[1]" = "$branch"; or continue
        # `string join`, not "$a\t$b": Fish leaves escapes alone inside double
        # quotes, so the quoted form writes a literal backslash and a t, and the
        # `string split \t` on the other side finds one field instead of two.
        set -g _gw_reply (string join \t -- $fields[2] $fields[3])
        return 0
    end
    return 1
end
