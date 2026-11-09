#!/bin/bash
# gamble-guard installer. Run with sudo. Once installed it is permanent: there is no uninstall.
#   sudo ./install.sh                         install or update
#   PARTNER=1 sudo ./install.sh               an accountability partner's passphrase becomes the only way to remove it
#   LOCK_DAYS=90 sudo ./install.sh            finite lock instead of forever: removal becomes possible after 90 days
#   VPN_BLOCK=0 sudo ./install.sh             skip the VPN/proxy/DoH bypass list (on by default; remote-work tools allowlisted)
#   LIST_URL=... sudo ./install.sh            use a different blocklist
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }

# Say it before anything happens. Read from the terminal even when piped through curl;
# with no terminal (automation), GG_YES=1 is the only way past.
if [ "${GG_YES:-0}" != 1 ]; then
  cat <<'WARN' >&2

  This is no joke. Once gamble-guard is installed, it cannot be uninstalled.
  Not in a week, not in a year. There is no uninstall command.
  Are you sure this is what you want to do?
  (Are you sure you want to save yourself? Pour la dérogation... there is none.)

WARN
  if [ -r /dev/tty ]; then
    printf '  Type YES to continue: ' >&2; read -r ANS < /dev/tty
  else
    echo "  No terminal to confirm on. Re-run with GG_YES=1 to accept." >&2; exit 1
  fi
  [ "$ANS" = "YES" ] || { echo "Nothing installed." >&2; exit 1; }
fi

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

# VPN/proxy/DoH bypass routes are closed by default; VPN_BLOCK=0 opts out
if [ "${VPN_BLOCK:-1}" != "0" ]; then
  if [ -f "$SRC/lists/vpn.txt" ]; then install -m 644 "$SRC/lists/vpn.txt" "$SHARE/vpn.txt"; touch "$SHARE/vpn-block"
    echo "    VPN/proxy bypass list enabled ($(wc -l < "$SHARE/vpn.txt" | tr -d ' ') domains)."
  else echo "    (no lists/vpn.txt in this checkout; VPN block skipped)"; fi
fi

# LOCK_DAYS=N: a finite lock instead of forever. Removal becomes possible on this date; before it,
# the only exit is an accountability partner's passphrase, if one exists.
if [ "${LOCK_DAYS:-0}" -gt 0 ] 2>/dev/null; then
  UNTIL=$(( $(date +%s) + LOCK_DAYS * 86400 ))
  printf '%s\n' "$UNTIL" > "$SHARE/locked-until"
  echo "    Locked until $(date -r "$UNTIL" '+%Y-%m-%d'): removal becomes possible after that."
fi

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
  "$SHARE/blocklist.txt" "$SHARE/pristine"/* "$SHARE/locked-until" "$SHARE/vpn.txt" "$SHARE/vpn-block" 2>/dev/null || true

echo
echo "$COUNT domains blocked across Chrome, Firefox and Safari."
echo "Two daemons re-apply it every 120s and restore each other if deleted."
echo "System DNS now goes through Mullvad's family resolver (194.242.2.6), which also filters"
echo "gambling - that catches new mirrors before the list does. Tailscale is left alone."
echo "Turn OFF iCloud Private Relay (System Settings > Apple Account > iCloud) or Safari bypasses it."
echo "Verify:  dscacheutil -q host -a name bet365.com"
echo
echo "Done. Permanent: there is no uninstall."
[ -f "$SHARE/partner.sha256" ] && echo "Partner passphrase: set. It is the only way to remove this."
[ -f "$SHARE/locked-until" ] && echo "Lock: removal becomes possible on $(date -r "$(cat "$SHARE/locked-until")" '+%Y-%m-%d')."

# congratulations page, in the browser of whoever ran sudo; never a failure
URL="https://prime-server.github.io/gamble-guard/"
if [ -n "${SUDO_USER:-}" ]; then sudo -u "$SUDO_USER" open "$URL" 2>/dev/null || true
else open "$URL" 2>/dev/null || true; fi
