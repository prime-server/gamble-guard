#!/bin/bash
# Rebuilds lists/ from every actively maintained public gambling blocklist.
# Runs weekly in GitHub Actions (see .github/workflows/update-blocklist.yml); clients pull the result.
# CI (GNU tools) is the canonical build; BSD sed/grep on macOS silently drop some lines.
# This is the "research" step: hundreds of volunteers already hunt new casinos daily - we aggregate them.
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCES=(
  "https://blocklistproject.github.io/Lists/gambling.txt"
  "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/gambling-onlydomains.txt"
  "https://raw.githubusercontent.com/Sinfonietta/hostfiles/master/gambling-hosts"
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts"
)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0
for u in "${SOURCES[@]}"; do
  if curl -fsSL --max-time 180 "$u" -o "$T/src.$ok"; then ok=$((ok+1)); echo "fetched $u"; else echo "skipped $u" >&2; fi
done
[ "$ok" -ge 2 ] || { echo "too few sources reachable ($ok); keeping existing lists" >&2; exit 1; }

# normalise: "0.0.0.0 host", "127.0.0.1 host", "*.host", "||host^", bare "host" -> lowercase bare domain
cat "$T"/src.* | tr -d '\r' | tr 'A-Z' 'a-z' \
  | sed -E 's/#.*$//; s/^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+//; s/^\*\.//; s/^\|\|//; s/\^$//; s/\s+$//' \
  | grep -E '^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$' \
  | grep -vE '^(localhost|localhost\.localdomain|broadcasthost|local)$' \
  | sort -u > "$T/all"

# brand mirrors: the same brand reappears on a new TLD within days of being blocked
TLDS="com io net cc bet casino games gg win vip co ag eu us to me app xyz"
grep -vE '^\s*#|^\s*$' tools/brands.txt | tr ' ' '\n' | grep . | while read -r b; do
  for t in $TLDS; do for p in "" "www." "m."; do echo "$p$b.$t"; done; done
done | sort -u > "$T/mirrors"

sort -u "$T/all" "$T/mirrors" > "$T/full"
# compact (Windows): entries whose first label starts with a known brand, plus the mirrors.
# The Windows DNS client stalls above ~50k hosts lines (measured: >25 s/lookup at 344k).
# first label must BE the brand (optionally brand-NNN / brand-xx), not merely start with it:
# "coral" must not drag in every coral*.com on the internet.
pat="^(www\.|m\.)?($(grep -vE '^\s*#|^\s*$' tools/brands.txt | tr ' ' '\n' | grep . | sed 's/[.-]/\\&/g' | paste -sd'|' -))(-?[0-9]{1,4}|-[a-z]{1,6})?\."
grep -E "$pat" "$T/full" | sort -u "$T/mirrors" - > "$T/compact"

# refuse to publish a broken build
for f in full compact; do
  n=$(wc -l < "$T/$f" | tr -d ' ')
  [ "$f" = full ] && min=100000 || min=5000
  [ "$n" -ge "$min" ] || { echo "$f has only $n entries; refusing" >&2; exit 1; }
done
# never block the infrastructure people depend on
for d in google.com apple.com microsoft.com github.com cloudflare.com amazonaws.com icloud.com; do
  grep -qxF "$d" "$T/full" && { echo "false positive: $d in list; refusing" >&2; exit 1; }
done

# optional VPN/proxy/DoH-bypass list (clients enable with VPN_BLOCK=1). Gamban and BetBlocker
# both close these routes; we do it with an allowlist so remote-work tools keep working.
VPN_SRC="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/doh-vpn-proxy-bypass-onlydomains.txt"
if curl -fsSL --max-time 180 "$VPN_SRC" -o "$T/vpn.raw"; then
  tr -d '\r' < "$T/vpn.raw" | tr 'A-Z' 'a-z' | sed -E 's/#.*$//; s/^\*\.//; s/\s+$//' \
    | grep -E '^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$' | sort -u > "$T/vpn.all"
  grep -vE '^\s*#|^\s*$' tools/vpn-allow.txt | sort -u > "$T/vpn.allow"
  # drop allowlisted domains and anything under them
  awk 'NR==FNR{a[$0]=1; next} { d=$0; keep=1; while (d != "") { if (d in a) {keep=0; break}; i=index(d,"."); if(!i) break; d=substr(d,i+1) } if(keep) print }' "$T/vpn.allow" "$T/vpn.all" > "$T/vpn"
  [ "$(wc -l < "$T/vpn" | tr -d ' ')" -ge 5000 ] && sed 's/^/0.0.0.0 /' "$T/vpn" > lists/vpn.txt
fi

sed 's/^/0.0.0.0 /' "$T/full"    > lists/full.txt
sed 's/^/0.0.0.0 /' "$T/compact" > lists/compact.txt
printf 'built=%s\nfull=%s\ncompact=%s\nvpn=%s\nsources=%s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" \
  "$(wc -l < lists/full.txt | tr -d ' ')" "$(wc -l < lists/compact.txt | tr -d ' ')" \
  "$( [ -f lists/vpn.txt ] && wc -l < lists/vpn.txt | tr -d ' ' || echo 0)" "$ok" > lists/VERSION
cat lists/VERSION
