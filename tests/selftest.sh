#!/bin/bash
# Exercises the hosts-rewrite logic against a temporary file. Needs no root.
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
chk(){ [ "$2" = "$3" ] && echo "  ok   $1" || { echo "  FAIL $1 (got $2, want $3)"; fail=1; }; }

printf '127.0.0.1\tlocalhost\n10.0.0.5\tmy-nas\n' > "$T/hosts"
printf '0.0.0.0 bet365.com\n0.0.0.0 stake.com\n' > "$T/list"
run(){ LIST="$T/list" HOSTS="$T/hosts" SKIP_BROWSERS=1 SKIP_DNS=1 SKIP_REFRESH=1 ./src/gambleguard; }

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


# --- upstream resolver: which services get touched --------------------------
# a fake networksetup on PATH logs what the guard would set; Wi-Fi is already correct
mkdir -p "$T/bin"; : > "$T/set.log"
cat > "$T/bin/networksetup" <<EOF
#!/bin/bash
case "\$1" in
  -listallnetworkservices) printf '%s\n' 'An asterisk (*) denotes that a network service is disabled.' \
    'Wi-Fi' 'USB LAN' '*Bluetooth PAN' 'Thunderbolt Bridge' 'Tailscale' ;;
  -getdnsservers) [ "\$2" = Wi-Fi ] && printf '194.242.2.6\n2a07:e340::6\n' || echo "There aren't any DNS Servers set on \$2." ;;
  -setdnsservers) echo "\${*:2}" >> "$T/set.log" ;;
esac
EOF
chmod +x "$T/bin/networksetup"
PATH="$T/bin:$PATH" LIST="$T/list" HOSTS="$T/hosts" SKIP_BROWSERS=1 SKIP_REFRESH=1 ./src/gambleguard
chk "dns: sets the unconfigured service" "$(grep -cx 'USB LAN 194.242.2.6 2a07:e340::6' "$T/set.log")" 1
chk "dns: skips set/disabled/Tailscale/Thunderbolt" "$(wc -l < "$T/set.log" | tr -d ' ')" 1

# --- cooling-off gate -----------------------------------------------------
T2=$(mktemp -d); trap 'rm -rf "$T" "$T2"' EXIT
out=$(SHARE="$T2" ./uninstall.sh --status)
chk "status: nothing requested" "$(echo "$out" | grep -c 'No removal requested')" 1
printf '%s\n' "$(date +%s)" > "$T2/unlock.request"
out=$(SHARE="$T2" ./uninstall.sh --status)
chk "status: wait reported"     "$(echo "$out" | grep -c 'left')" 1
printf '%s\n' "$(( $(date +%s) - 8*86400 ))" > "$T2/unlock.request"
out=$(SHARE="$T2" ./uninstall.sh --status)
chk "status: wait elapsed"      "$(echo "$out" | grep -c 'complete')" 1
out=$(SHARE="$T2" DELAY_DAYS=30 ./uninstall.sh --status)
chk "status: honours DELAY_DAYS" "$(echo "$out" | grep -c 'left')" 1
exit $fail
