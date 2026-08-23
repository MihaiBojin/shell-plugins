function fish_prompt --description 'Minimal two-line, Pure-like prompt'
    # Capture the exit status before anything below overwrites it.
    set -l last_status $status

    # Blank separator line, then the working directory, then the chevron:
    #
    #   <blank>
    #   ~/some/directory
    #   ❯
    #
    # No git state, no async workers, no external commands, no runtime or
    # cloud context. `set_color`, `printf` and `prompt_pwd` are all Fish's own,
    # so rendering a prompt forks nothing.
    printf '\n'

    set_color blue
    # prompt_pwd ends its output with a newline, which is the line break
    # between the directory and the chevron — no extra printf needed.
    # --dir-length=0 keeps every component in full rather than abbreviating.
    prompt_pwd --dir-length=0
    set_color normal

    # Magenta after a command that worked, red after one that did not.
    if test $last_status -eq 0
        set_color magenta
    else
        set_color red
    end

    printf '❯ '
    set_color normal
end
