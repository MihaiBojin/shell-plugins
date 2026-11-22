# coreutils — the two long listings, as Fish abbreviations.
#
# Fish's own ls function already colours a terminal. grep, gls and diff get
# --color=auto from functions/ instead.

if status is-interactive
    abbr --add ll -- 'ls -lh'
    abbr --add lla -- 'ls -alh'
end
