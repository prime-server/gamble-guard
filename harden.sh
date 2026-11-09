#!/bin/bash
# harden.sh - the only configuration gamble-guard cannot be removed from.
#
# Creates a second admin account for an accountability partner, then demotes the
# everyday account to Standard. A Standard user cannot run sudo, so they cannot
# remove the blocker, the daemons, or the hosts entries. The partner holds the
# only admin password.
#
#   sudo ./harden.sh partneradmin "Partner Name"
#
# Reversing this needs the partner's password. That is the entire point.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./harden.sh <adminuser> \"Full Name\""; exit 1; }

NEWADMIN="${1:?usage: sudo ./harden.sh <adminuser> \"Full Name\"}"
FULLNAME="${2:-Accountability Partner}"
TARGET="${SUDO_USER:-$(stat -f %Su /dev/console)}"

[ "$NEWADMIN" = "$TARGET" ] && { echo "The partner account must not be your own account."; exit 1; }
id "$NEWADMIN" >/dev/null 2>&1 && { echo "User $NEWADMIN already exists. Pick another name."; exit 1; }

cat <<WARN

  This will:
    1. create admin account '$NEWADMIN' ($FULLNAME)
    2. REMOVE admin rights from '$TARGET'

  After this you cannot install software, change system settings, or remove
  gamble-guard without '$NEWADMIN'. Have the partner set the password THEMSELVES
  on the next screen and not tell you.

  Type exactly: I UNDERSTAND
WARN
read -r CONFIRM
[ "$CONFIRM" = "I UNDERSTAND" ] || { echo "Aborted."; exit 1; }

NEXTID=$(( $(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1) + 1 ))
dscl . -create "/Users/$NEWADMIN"
dscl . -create "/Users/$NEWADMIN" UserShell /bin/zsh
dscl . -create "/Users/$NEWADMIN" RealName "$FULLNAME"
dscl . -create "/Users/$NEWADMIN" UniqueID "$NEXTID"
dscl . -create "/Users/$NEWADMIN" PrimaryGroupID 20
dscl . -create "/Users/$NEWADMIN" NFSHomeDirectory "/Users/$NEWADMIN"
createhomedir -c -u "$NEWADMIN" >/dev/null 2>&1 || true
dseditgroup -o edit -a "$NEWADMIN" -t user admin

echo
echo ">>> Hand the keyboard to your partner. They set the password now:"
passwd "$NEWADMIN"

dseditgroup -o edit -d "$TARGET" -t user admin
echo
echo "Done. '$TARGET' is now a Standard user and cannot remove gamble-guard."
echo "Admin is '$NEWADMIN'. If that password is lost, recovery means reinstalling macOS."
