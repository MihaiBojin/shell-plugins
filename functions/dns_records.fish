function dns_records --description 'Print the common DNS record types for a domain'
    set -l domain $argv[1]

    if test -z "$domain"
        echo "usage: dns_records DOMAIN" >&2
        return 2
    end

    if not command --query dig
        echo "dns_records: dig is not installed" >&2
        return 127
    end

    for rec in A AAAA CNAME TXT NS MX CAA SRV
        echo "$domain $rec..."
        command dig "$domain" $rec +short 2>/dev/null
        echo
    end
end
