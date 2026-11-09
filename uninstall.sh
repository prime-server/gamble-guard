#!/bin/bash
# Removes gamble-guard - but not on impulse.
#
# Removal is gated two ways:
#   * if an accountability partner set a passphrase at install, it is required;
#   * otherwise removal must be REQUESTED, then confirmed after a cooling-off
#     period (default 7 days). The first run starts the clock and exits.
#
#   sudo ./uninstall.sh           request removal, or complete it if the wait is up
#   sudo ./uninstall.sh --status  how long is left
set -euo pipefail

SHARE="${SHARE:-/usr/local/share/gambleguard}"
REQ="$SHARE/unlock.request"
PARTNER="$SHARE/partner.sha256"
DELAY_DAYS="${DELAY_DAYS:-7}"
DELAY=$(( DELAY_DAYS * 86400 ))
NOW=$(date +%s)

status() {
  if [ -f "$REQ" ]; then
    LEFT=$(( $(cat "$REQ") + DELAY - NOW ))
    [ "$LEFT" -le 0 ] && echo "Cooling-off complete. Re-run to remove." \
      || echo "Removal requested. $(( LEFT / 3600 ))h $(( (LEFT % 3600) / 60 ))m left."
  else
    echo "No removal requested. gamble-guard is active."
  fi
}
[ "${1:-}" = "--status" ] && { status; exit 0; }   # read-only, needs no root

[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh"; exit 1; }

if [ -f "$PARTNER" ]; then
  printf "Accountability passphrase: " >&2
  read -rs PASS; echo >&2
  GOT=$(printf '%s' "$PASS" | shasum -a 256 | awk '{print $1}')
  if [ "$GOT" != "$(cat "$PARTNER")" ]; then
    echo "Wrong passphrase. Ask the person who holds it." >&2; exit 1
  fi
  echo "Passphrase accepted."
else
  if [ ! -f "$REQ" ]; then
    chflags noschg "$SHARE" 2>/dev/null || true
    printf '%s\n' "$NOW" > "$REQ"
    echo
    echo "Removal requested. gamble-guard keeps working for $DELAY_DAYS days."
    echo "Re-run this after that to finish. Check progress: sudo ./uninstall.sh --status"
    echo
    echo "If this is a craving rather than a decision, it will pass. $DELAY_DAYS days from"
    echo "now you can do this calmly - or find you no longer want to."
    exit 0
  fi
  LEFT=$(( $(cat "$REQ") + DELAY - NOW ))
  if [ "$LEFT" -gt 0 ]; then
    echo "Still cooling off: $(( LEFT / 3600 ))h $(( (LEFT % 3600) / 60 ))m left." >&2
    exit 1
  fi
fi

MARK_A="# >>> gamble-guard >>>"
MARK_B="# <<< gamble-guard <<<"
for L in com.gambleguard com.gambleguard.watch; do
  launchctl bootout "system/$L" 2>/dev/null || true
done
chflags noschg /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist /Library/LaunchDaemons/com.gambleguard.watch.plist \
  "$SHARE" "$SHARE/blocklist.txt" /etc/hosts 2>/dev/null || true
chflags -R noschg "$SHARE" 2>/dev/null || true
rm -f /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist /Library/LaunchDaemons/com.gambleguard.watch.plist
rm -rf "$SHARE"

# hand DNS back to DHCP, but only on services the guard pointed at the filtering resolver
DNS="194.242.2.6 2a07:e340::6"
networksetup -listallnetworkservices 2>/dev/null | grep -v -e '^An asterisk' -e '^\*' | while IFS= read -r S; do
  [ "$(networksetup -getdnsservers "$S" 2>/dev/null | paste -sd' ' -)" = "$DNS" ] && networksetup -setdnsservers "$S" empty
done || true
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
sed "/^${MARK_A}\$/,/^${MARK_B}\$/d" /etc/hosts > "$TMP"
cat "$TMP" > /etc/hosts; chmod 644 /etc/hosts
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
echo "gamble-guard removed. If this was the addiction talking, reinstall: sudo ./install.sh"
