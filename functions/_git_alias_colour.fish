function _git_alias_colour -d 'Whether a message this package writes may carry colour'
    # Both writers ask: _git_alias_say for its level, _git_alias_announce for
    # its dim. One place answers, so the question is settled once rather than
    # per message.
    #
    # stderr, because that is where every message goes. A redirected one is
    # read by something that wants text, not escapes.
    isatty stderr
end
