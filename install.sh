#!/bin/bash
# gamble-guard installer. Run with sudo.
#   sudo ./install.sh                         install or update
#   PARTNER=1 sudo ./install.sh               also set an accountability passphrase
#   LIST_URL=... sudo ./install.sh            use a different blocklist
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }

LIST_URL="${LIST_URL:-https://blocklistproject.github.io/Lists/gambling.txt}"
SHARE=/usr/local/share/gambleguard
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo .)"

# Piped in through curl? Then there is no checkout next to this script - fetch one.
if [ ! -f "$SRC/src/gambleguard" ]; then
  echo "==> fetching gamble-guard"
  BOOT=$(mktemp -d)
  curl -fsSL --max-time 120 https://github.com/prime-server/gamble-guard/archive/refs/heads/main.tar.gz \
    | tar xz -C "$BOOT"
  SRC="$BOOT/gamble-guard-main"
  [ -f "$SRC/src/gambleguard" ] || { echo "Could not fetch gamble-guard. Check your connection."; exit 1; }
fi

echo "==> fetching blocklist"
TMP=$(mktemp); CLEAN=$(mktemp)
trap 'rm -f "$TMP" "$CLEAN"' EXIT
if [ -f "$SRC/lists/full.txt" ]; then
  cp "$SRC/lists/full.txt" "$TMP"        # prebuilt weekly aggregate (~660k domains)
else
  curl -fsSL --max-time 120 "$LIST_URL" -o "$TMP"
fi
grep -E '^0\.0\.0\.0 [a-zA-Z0-9][a-zA-Z0-9.-]*$' "$TMP" | tr 'A-Z' 'a-z' | sort -u > "$CLEAN"
[ -f "$SRC/extra-domains.txt" ] && cat "$SRC/extra-domains.txt" >> "$CLEAN" && sort -u "$CLEAN" -o "$CLEAN"
COUNT=$(grep -c . "$CLEAN" || true)
[ "$COUNT" -gt 1000 ] || { echo "Blocklist looks wrong ($COUNT entries). Aborting."; exit 1; }
echo "    $COUNT domains"

# allow a clean re-run over a previous install
chflags -R noschg "$SHARE" 2>/dev/null || true
chflags noschg /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist \
  /Library/LaunchDaemons/com.gambleguard.watch.plist /etc/hosts 2>/dev/null || true

echo "==> installing"
mkdir -p "$SHARE/pristine"
install -m 644 "$CLEAN" "$SHARE/blocklist.txt"
touch "$SHARE/.refreshed"
install -m 755 "$SRC/src/gambleguard"       /usr/local/bin/gambleguard
install -m 755 "$SRC/src/gambleguard-watch" /usr/local/bin/gambleguard-watch
install -m 644 -o root -g wheel "$SRC/src/com.gambleguard.plist"       /Library/LaunchDaemons/com.gambleguard.plist
install -m 644 -o root -g wheel "$SRC/src/com.gambleguard.watch.plist" /Library/LaunchDaemons/com.gambleguard.watch.plist
# pristine copies the watchdogs restore from
install -m 644 "$SRC/src/gambleguard"       "$SHARE/pristine/gambleguard"
install -m 644 "$SRC/src/gambleguard-watch" "$SHARE/pristine/gambleguard-watch"
install -m 644 "$SRC/src/com.gambleguard.plist"       "$SHARE/pristine/com.gambleguard.plist"
install -m 644 "$SRC/src/com.gambleguard.watch.plist" "$SHARE/pristine/com.gambleguard.watch.plist"

if [ "${PARTNER:-0}" = "1" ]; then
  echo
  echo ">>> Hand the keyboard to your accountability partner."
  printf "    Passphrase (hidden, you must not see it): "
  read -rs P1; echo
  printf "    Again: "; read -rs P2; echo
  [ -n "$P1" ] && [ "$P1" = "$P2" ] || { echo "Passphrases empty or did not match."; exit 1; }
  printf '%s' "$P1" | shasum -a 256 | awk '{print $1}' > "$SHARE/partner.sha256"
  chmod 600 "$SHARE/partner.sha256"
  echo "    Stored. Removal now requires this passphrase."
fi

for L in com.gambleguard com.gambleguard.watch; do
  launchctl bootout "system/$L" 2>/dev/null || true
  launchctl bootstrap system "/Library/LaunchDaemons/$L.plist"
done
/usr/local/bin/gambleguard          # hosts block + upstream resolver + Chrome/Firefox DNS policy

chflags schg /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist \
  /Library/LaunchDaemons/com.gambleguard.watch.plist \
  "$SHARE/blocklist.txt" "$SHARE/pristine"/* 2>/dev/null || true

echo
echo "Done. $COUNT domains blocked across Chrome, Firefox and Safari."
echo "Two daemons re-apply it every 120s and restore each other if deleted."
echo "System DNS now goes through Mullvad's family resolver (194.242.2.6), which also filters"
echo "gambling - that catches new mirrors before the list does. Tailscale is left alone."
echo "Turn OFF iCloud Private Relay (System Settings > Apple Account > iCloud) or Safari bypasses it."
[ -f "$SHARE/partner.sha256" ] && echo "Removal requires the partner passphrase." \
  || echo "Removal requires a 7-day cooling-off: sudo ./uninstall.sh"
echo "Verify:  dscacheutil -q host -a name bet365.com"
