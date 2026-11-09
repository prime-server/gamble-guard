#!/bin/bash
# Removes gamble-guard completely. Run with sudo.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh"; exit 1; }

MARK_A="# >>> gamble-guard >>>"
MARK_B="# <<< gamble-guard <<<"
SHARE=/usr/local/share/gambleguard
BIN=/usr/local/bin/gambleguard
PLIST=/Library/LaunchDaemons/com.gambleguard.plist

launchctl bootout system "$PLIST" 2>/dev/null || true
chflags noschg "$BIN" "$PLIST" "$SHARE/blocklist.txt" /etc/hosts 2>/dev/null || true
rm -f "$BIN" "$PLIST"; rm -rf "$SHARE"

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
sed "/^${MARK_A}\$/,/^${MARK_B}\$/d" /etc/hosts > "$TMP"
install -m 644 -o root -g wheel "$TMP" /etc/hosts
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true

echo "gamble-guard removed."
