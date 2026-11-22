# coreutils — the long listing, as a Fish abbreviation.
#
# Fish's own ls function already colours a terminal. grep, gls and diff get
# --color=auto from functions/ instead.

if status is-interactive
    abbr --add ll -- 'ls -alh --color=auto'
end
