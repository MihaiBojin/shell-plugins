function et --description 'Eternal Terminal, with the local terminal state reset around it'
    # Chain: WezTerm/Ghostty -> et -> remote tmux. tmux runs in the alternate
    # screen buffer (?1049h) with application cursor keys (?1h). On a clean
    # disconnect tmux DECRSTs them; on an abrupt et death (network drop /
    # crash) it can't, so the outer terminal stays stuck in the alt screen.
    # While in the alt screen WezTerm translates the mouse wheel into arrow
    # keys -> the shell walks history instead of scrolling the pane.
    # (Confirmed: DECRST-ing the mouse modes alone does nothing; leaving the
    # alt screen is what fixes it.)
    #
    # Reset before connecting, so reconnecting into a surviving tmux session
    # starts from a clean baseline, and after et returns — which happens on a
    # crash too, since the function resumes when et's process dies.
    _shell_terminal_reset
    command et $argv
    set -l rc $status
    _shell_terminal_reset
    return $rc
end
