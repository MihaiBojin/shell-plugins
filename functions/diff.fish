function diff --wraps diff -d 'diff, coloured on a terminal where diff can'
    # An older BSD diff has no --color, so ask once per shell.
    if not set -q __shell_plugins_diff_colour
        set -g __shell_plugins_diff_colour
        command diff --color /dev/null /dev/null >/dev/null 2>&1
        and set -g __shell_plugins_diff_colour --color=auto
    end
    command diff $__shell_plugins_diff_colour $argv
end
