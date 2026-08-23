function _shell_terminal_reset --description 'Leave the alternate screen and clear stuck terminal modes'
    # Alt-screen buffers (?1049/?1047/?47), application cursor keys (?1) and
    # the mouse-tracking modes (?1000-?1007). See functions/et.fish for why.
    printf '\e[?1049l\e[?1047l\e[?47l\e[?1l\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1007l'
end
