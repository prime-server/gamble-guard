#!/bin/bash
# Exercises the hosts-rewrite logic against a temporary file. Needs no root.
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
chk(){ [ "$2" = "$3" ] && echo "  ok   $1" || { echo "  FAIL $1 (got $2, want $3)"; fail=1; }; }

printf '127.0.0.1\tlocalhost\n10.0.0.5\tmy-nas\n' > "$T/hosts"
printf '0.0.0.0 bet365.com\n0.0.0.0 stake.com\n' > "$T/list"
run(){ LIST="$T/list" HOSTS="$T/hosts" ./src/gambleguard; }

run
chk "block applied"        "$(grep -c '0.0.0.0 bet365.com' "$T/hosts")" 1
chk "existing entries kept" "$(grep -c 'my-nas' "$T/hosts")" 1
b=$(md5 -q "$T/hosts"); run
chk "idempotent"           "$(md5 -q "$T/hosts")" "$b"
grep -v '0.0.0.0' "$T/hosts" > "$T/t" && mv "$T/t" "$T/hosts"
run
chk "self-heals"           "$(grep -c '0.0.0.0 bet365.com' "$T/hosts")" 1
chk "no duplicate block"   "$(grep -c 'gamble-guard >>>' "$T/hosts")" 1
chk "entries still kept"   "$(grep -c 'my-nas' "$T/hosts")" 1
exit $fail
