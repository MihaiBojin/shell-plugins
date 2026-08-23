#
# dns — DNS lookup helpers.
#
#   dns_records DOMAIN   dump the common record types for a domain
#
# Requires `dig` (bind-utils / dnsutils) at call time, not at load time.
#
fpath=( ${${(%):-%x}:A:h}/functions $fpath )
autoload -Uz dns_records
