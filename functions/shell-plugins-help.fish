function shell-plugins-help -d 'List every shortcut shell-plugins defines'
    # The list sits beside this file, and Zsh reads the same one.
    set -l file (path dirname (functions --details shell-plugins-help))/shell-plugins-help.tsv
    if not test -r $file
        echo "shell-plugins-help: cannot read $file" >&2
        return 1
    end

    set -l rows (string match --regex -- '.+' <$file)
    set -l names (string replace --regex -- '\t.*' '' $rows)
    set -l width (math max (string length -- $names | string join ,))
    for i in (seq (count $rows))
        printf '%s  %s\n' (string pad --right --width $width -- $names[$i]) \
            (string replace --regex -- '^[^\t]*\t' '' $rows[$i])
    end
end
