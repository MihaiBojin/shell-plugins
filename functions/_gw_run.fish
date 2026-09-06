function _gw_run -d 'Run a command behind a spinner; its output lands in $_gw_reply'
    # _gw_run LABEL COMMAND [ARG...]
    #
    # The command's output — stdout and stderr merged — goes into $_gw_reply and
    # is printed only when the command fails. Its exit status is passed through.
    # Anything that can reach the network gets one of these, so a slow fetch
    # looks like work rather than a hang, and `git worktree add`'s progress
    # stops arriving in the middle of a command's own output.
    #
    # Everything is written to stderr: these helpers run inside command
    # substitutions whose stdout is the caller's return value.
    set -l msg $argv[1]
    set -l cmd $argv[2..-1]
    set -g _gw_reply ''

    # The icons follow the locale, not the terminal: a result line is printed
    # whether or not anything animated.
    set -l frames '|' '/' '-' '\\'
    set -l tick +
    set -l cross !
    if string match --quiet --regex -- 'UTF-?8|utf-?8' "$LC_ALL$LC_CTYPE$LANG"
        set frames ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
        set tick ✓
        set cross ✗
    end

    set -l rc 0
    if not isatty stderr
        # Nothing to animate over, so nothing is backgrounded either. This is
        # also the path every test and every CI run takes, which makes the
        # capture the part that is actually exercised.
        set -g _gw_reply ($cmd 2>&1 | string collect)
        set rc $pipestatus[1]
    else
        set -l dir /tmp
        test -n "$TMPDIR"; and set dir $TMPDIR
        set -l tmp (mktemp $dir/gw.XXXXXX 2>/dev/null | string collect)
        if test -z "$tmp"
            # No temporary file means no spinner, but $_gw_reply still has to be
            # the command's output: callers read it as the answer, and an empty
            # one reads as "the remote does not have that branch".
            set -g _gw_reply ($cmd 2>&1 | string collect)
            set rc $pipestatus[1]
        else
            # `wait` reports whether it waited, not how the job exited, so the
            # status travels through a file rather than through the builtin.
            begin
                $cmd >$tmp 2>&1
                echo $status >$tmp.rc
            end &
            set -l pid $last_pid

            # Give a fast command a moment to finish so nothing flickers, but
            # poll for it rather than sleep through it: a 5 ms command costs
            # 5 ms, and only a genuinely slow one waits the full 120 before the
            # spinner appears.
            set -l waited 0
            while test $waited -lt 12; and kill -0 $pid 2>/dev/null
                sleep 0.01
                set waited (math $waited + 1)
            end

            if kill -0 $pid 2>/dev/null
                set -l i 0
                set -l hint ''
                printf '\e[?25l' >&2
                while kill -0 $pid 2>/dev/null
                    set -l frame $frames[(math $i % (count $frames) + 1)]
                    printf '\r\e[2K%s[%s]%s %s%s' (set_color cyan) $frame (set_color normal) "$msg" "$hint" >&2
                    sleep 0.08
                    set i (math $i + 1)
                    # Git's own prompts — a passphrase, HTTPS credentials — are
                    # captured along with the rest of its output, so a wait for
                    # input looks exactly like a hang.
                    test $i -eq 120; and set hint ' (still waiting — ^C to cancel)'
                end
                printf '\r\e[2K\e[?25h' >&2
            end

            wait $pid 2>/dev/null
            set rc (cat $tmp.rc 2>/dev/null | string collect)
            test -n "$rc"; or set rc 1
            set -g _gw_reply (cat $tmp | string collect)
            rm -f $tmp $tmp.rc
        end
    end

    if test "$rc" -eq 0
        echo (set_color green)"[$tick]"(set_color normal)" $msg" >&2
    else
        echo (set_color red)"[$cross]"(set_color normal)" $msg" >&2
        for line in (string split \n -- $_gw_reply)
            test -n "$line"; and echo "    $line" >&2
        end
    end
    return $rc
end
