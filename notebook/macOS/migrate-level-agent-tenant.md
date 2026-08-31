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
