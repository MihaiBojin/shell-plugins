#
# eternal-terminal — wrap `et` so a dropped connection cannot leave the local
# terminal stuck in the alternate screen.
#
# Requires the `et` client at call time; loading this plugin without it is
# harmless, and running `et` then fails exactly as it would have anyway.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz et
