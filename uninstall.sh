#!/bin/bash
# Removes gamble-guard. By default it cannot: the blocker is permanent.
#
# Removal happens only if one of these applies:
#   * a finite lock was chosen at install (LOCK_DAYS=N) and its date has passed;
#   * an accountability partner set a passphrase at install (PARTNER=1) and types it.
#
#   sudo ./uninstall.sh           remove, if one of the above applies
#   ./uninstall.sh --status       which applies (needs no root)
set -euo pipefail

SHARE="${SHARE:-/usr/local/share/gambleguard}"
PARTNER="$SHARE/partner.sha256"
LOCK="$SHARE/locked-until"
NOW=$(date +%s)
lock_date(){ date -r "$(cat "$LOCK")" '+%Y-%m-%d'; }

status() {
  echo "Permanent: there is no uninstall."
  [ -f "$PARTNER" ] && echo "Partner passphrase: set" || echo "Partner passphrase: not set"
  [ -f "$LOCK" ] && echo "Lock: until $(lock_date)" || echo "Lock: forever"
}
[ "${1:-}" = "--status" ] && { status; exit 0; }   # read-only, needs no root

[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh"; exit 1; }

if [ -f "$LOCK" ] && [ "$(cat "$LOCK")" -le "$NOW" ]; then
  echo "Lock ended $(lock_date)."
elif [ -f "$PARTNER" ]; then
  printf "Accountability passphrase: " >&2
  read -rs PASS; echo >&2
  GOT=$(printf '%s' "$PASS" | shasum -a 256 | awk '{print $1}')
  if [ "$GOT" != "$(cat "$PARTNER")" ]; then
    echo "Wrong passphrase. Ask the person who holds it." >&2; exit 1
  fi
  echo "Passphrase accepted."
else
  echo "gamble-guard has no uninstall. It is permanent by design."
  [ -f "$LOCK" ] && echo "Your lock ends $(lock_date)."
  exit 1
fi

MARK_A="# >>> gamble-guard >>>"
MARK_B="# <<< gamble-guard <<<"
for L in com.gambleguard com.gambleguard.watch; do
  launchctl bootout "system/$L" 2>/dev/null || true
done
chflags noschg /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist /Library/LaunchDaemons/com.gambleguard.watch.plist \
  "$SHARE" "$SHARE/blocklist.txt" "$SHARE/locked-until" /etc/hosts 2>/dev/null || true
chflags -R noschg "$SHARE" 2>/dev/null || true
rm -f /usr/local/bin/gambleguard /usr/local/bin/gambleguard-watch \
  /Library/LaunchDaemons/com.gambleguard.plist /Library/LaunchDaemons/com.gambleguard.watch.plist
rm -rf "$SHARE"

# hand DNS back to DHCP, but only on services the guard pointed at the filtering resolver
# remove only OUR resolver entries; any other server (e.g. a still-working filter from
# another blocker) is left exactly where it was
networksetup -listallnetworkservices 2>/dev/null | grep -v -e '^An asterisk' -e '^\*' | while IFS= read -r S; do
  CUR=$(networksetup -getdnsservers "$S" 2>/dev/null | grep -E '^[0-9a-fA-F.:]+$')
  echo "$CUR" | grep -qE '^(194\.242\.2\.6|2a07:e340::6)$' || continue
  REST=$(echo "$CUR" | grep -vE '^(194\.242\.2\.6|2a07:e340::6)$' | paste -sd' ' -)
  if [ -n "$REST" ]; then networksetup -setdnsservers "$S" $REST; else networksetup -setdnsservers "$S" empty; fi
done || true
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
sed "/^${MARK_A}\$/,/^${MARK_B}\$/d" /etc/hosts > "$TMP"
cat "$TMP" > /etc/hosts; chmod 644 /etc/hosts
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
echo "gamble-guard removed. If this was the addiction talking, reinstall: sudo ./install.sh"
