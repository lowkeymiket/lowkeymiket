# Migrate the Level Agent Between RMM Tenants (macOS)

## Problem
The same four-tenant RMM consolidation covered Macs: each machine had to leave its old Level tenant and enroll in the new one, and the only delivery channel was the old tenant's own terminal session, which dies partway through the swap.

## Fix
The delivery wrapper writes the script to `/var/tmp` with a heredoc, then launches it backgrounded so it outlives the agent uninstall:

```bash
/bin/bash /var/tmp/level-migrate.sh >/var/tmp/level-migrate.out 2>&1 &
echo "migration_started"
```

The script itself runs the vendor uninstall, removes the agent identity/config (`/var/lib/level`), cleans up the app and binary, then runs the official install script with the new tenant's `LEVEL_API_KEY` exported.

## Safety / Notes
- Removing `/var/lib/level` is the critical step: a stale identity re-enrolls the Mac into the old tenant.
- Every step appends to logs in `/var/tmp` for post-migration review.
- Steps are individually non-fatal (`|| true`) so a missing artifact does not abort the swap.
- The API key is a placeholder; keys were per device group.

## Result
Combined with the Windows swap script, this gave a cross-platform remote path for consolidating four RMM tenants into one during the wider tenant-to-tenant migration.

## Notes
**Recovered exact source.** Only the tenant API key is a placeholder; the background launch is part of the recovered design.

## Script

```bash
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
```
