function _gw_remote_has_branch -a remote name -d 'Does REMOTE have a branch called NAME?'
    # One ref-advertisement round trip; protocol v2 filters server-side, so this
    # stays cheap on a repository with many refs.
    #
    # The full ref is the pattern, and the ref that comes back is compared in
    # full again, because `ls-remote` matches the tail of a ref path: a bare
    # NAME also matches every refs/heads/<anything>/NAME the remote has, and
    # answering yes to one of those sends gwa to fetch a branch that is not
    # there.
    test -n "$remote"; and test -n "$name"; or return 1

    # The status is read before the output. A failed ls-remote leaves its error
    # text in $_gw_reply, so a non-empty reply on its own would say "the remote
    # has it".
    _gw_run "asking $remote about '$name'" \
        git ls-remote --heads $remote "refs/heads/$name"
    or return 1

    for line in (string split \n -- $_gw_reply)
        set -l fields (string split \t -- $line)
        if test (count $fields) -ge 2; and test "$fields[2]" = "refs/heads/$name"
            return 0
        end
    end
    return 1
end
