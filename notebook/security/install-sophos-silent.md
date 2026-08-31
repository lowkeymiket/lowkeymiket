# Silent Sophos Endpoint Deployment via RMM

## Problem
The four-entity tenant consolidation covered endpoint protection too: four separate Sophos tenants were being merged into one, the same shape as the Level RMM consolidation elsewhere in this repository.

Migration testing surfaced a second, bigger problem. Sophos was stalling the Windows profile re-ACL step of the tenant migration (re-permissioning local profiles to the target-tenant identities), turning a few minutes per machine into days. The endpoint plan therefore became: remotely remove Sophos before migration, run the migration and re-ACL at normal speed, then silently reinstall Sophos into the consolidated tenant afterward, without user interaction and without the automation unexpectedly rebooting endpoints.

## Fix
This script is the reinstall leg. The PowerShell wrapper validates the packaged installer, creates a persistent log location, checks for another active Sophos install, launches the installer silently, and handles known installer return codes.

## Safety / Notes
- Fails early if the installer is missing from the automation package.
- Refuses to launch a second Sophos installer concurrently.
- Logs execution identity, progress, and exit code.
- Treats exit code `3010` as successful but reboot-required without initiating the restart.
- Flags `1641` because it indicates that the installer initiated a reboot.
- Sequencing mattered: reinstall only ran after the migration/re-ACL had completed on the endpoint.

## Result
Endpoints came through the migration with the re-ACL running at normal speed instead of days, then were re-protected in the consolidated Sophos tenant through a silent RMM push, with endpoint-side logs retained for any failed installs.

## Notes
**Recovered exact source with organization-specific installer naming sanitized.**
