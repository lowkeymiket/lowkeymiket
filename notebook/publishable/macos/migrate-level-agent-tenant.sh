#!/bin/bash
# Recovered tenant-swap script from a four-tenant RMM consolidation.
# Delivered through the OLD tenant's Level terminal and launched in the
# background so it survives the uninstall of the agent that delivered it
# (see the adjacent write-up for the delivery wrapper). API key is a placeholder.

LOG="/var/tmp/level-migrate.log"
OUT="/var/tmp/level-migrate.out"
NEW_KEY="INSERT API KEY HERE"

echo "=== START MIGRATION ===" >> "$LOG"

# Attempt uninstall (continue even if it errors)
if [ -x "/usr/local/bin/level" ]; then
  /usr/local/bin/level --action uninstall >> "$OUT" 2>&1 || true
fi

sleep 5

# Remove leftover identity/config
rm -rf /var/lib/level >> "$OUT" 2>&1 || true
rm -rf /Applications/Level.app >> "$OUT" 2>&1 || true
rm -f  /usr/local/bin/level >> "$OUT" 2>&1 || true

echo "Installing NEW tenant..." >> "$LOG"

export LEVEL_API_KEY="$NEW_KEY"
curl -fsSL https://downloads.level.io/install_mac_os.sh | bash >> "$OUT" 2>&1

echo "=== DONE MIGRATION ===" >> "$LOG"
