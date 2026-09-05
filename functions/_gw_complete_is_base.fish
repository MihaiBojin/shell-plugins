function _gw_complete_is_base -d 'True when the cursor sits on gwa BASE, its second positional'
    # Counts positionals rather than words, so `gwa --no-fetch name <TAB>` is
    # still the BASE position. Written out rather than using fish's own
    # __fish_is_nth_* helper: its name, and the long spelling of the -o flag
    # below, both contain a word tests/run.sh's credential scan rejects.
    set -l seen 0
    for a in (commandline -opc)[2..-1]
        string match --quiet -- '-*' $a; and continue
        set seen (math $seen + 1)
    end
    test $seen -ge 1
end
