#!/bin/bash
# gamble-guard installer. Run with sudo.
#   sudo ./install.sh                 install or update
#   LIST_URL=... sudo ./install.sh    use a different blocklist
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }

LIST_URL="${LIST_URL:-https://blocklistproject.github.io/Lists/gambling.txt}"
SHARE=/usr/local/share/gambleguard
BIN=/usr/local/bin/gambleguard
PLIST=/Library/LaunchDaemons/com.gambleguard.plist
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> fetching blocklist"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
curl -fsSL --max-time 120 "$LIST_URL" -o "$TMP"

# normalise to "0.0.0.0 domain", lowercase, deduped
CLEAN=$(mktemp)
grep -E '^0\.0\.0\.0 [a-zA-Z0-9][a-zA-Z0-9.-]*$' "$TMP" | tr 'A-Z' 'a-z' | sort -u > "$CLEAN"
COUNT=$(grep -c . "$CLEAN" || true)
[ "$COUNT" -gt 1000 ] || { echo "Blocklist looks wrong ($COUNT entries). Aborting."; rm -f "$CLEAN"; exit 1; }
echo "    $COUNT domains"

# allow a clean re-run over a previous install
chflags noschg "$BIN" "$PLIST" "$SHARE/blocklist.txt" /etc/hosts 2>/dev/null || true

echo "==> installing"
mkdir -p "$SHARE"
install -m 644 "$CLEAN" "$SHARE/blocklist.txt"; rm -f "$CLEAN"
install -m 755 "$SRC/src/gambleguard" "$BIN"
install -m 644 -o root -g wheel "$SRC/src/com.gambleguard.plist" "$PLIST"

launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
"$BIN"

# A browser's own DNS-over-HTTPS resolves names itself and never consults
# /etc/hosts, which would silently defeat all of the above.
if [ -d "/Applications/Google Chrome.app" ]; then
  defaults write /Library/Preferences/com.google.Chrome DnsOverHttpsMode -string "off"
  defaults write /Library/Preferences/com.google.Chrome BuiltInDnsClientEnabled -bool false
  echo "==> disabled Chrome secure DNS (restart Chrome to apply)"
fi

# make the mechanism itself non-trivial to delete
chflags schg "$BIN" "$PLIST" "$SHARE/blocklist.txt"

echo
echo "Done. $COUNT domains blocked, guard re-applies every 120s."
echo "Verify:  dscacheutil -q host -a name bet365.com"
