#!/bin/bash
# Count asahi-alarm image installs by unique IP from access logs

if [ $# -eq 0 ]; then
    echo "Usage: $0 <accesslog> [accesslog...]"
    exit 1
fi

cat "$@" \
    | grep '" 206 ' \
    | grep -oE '([0-9a-f.:]+) - - .*(asahi-[a-z-]+\.zip)' \
    | sed -E 's/^([^ ]+) .*(asahi-[a-z-]+\.zip)/\2 \1/' \
    | sort -u \
    | awk '{print $1}' \
    | sort \
    | uniq -c \
    | sort -rn \
    | awk '{print; total += $1} END {print total, "total"}'
