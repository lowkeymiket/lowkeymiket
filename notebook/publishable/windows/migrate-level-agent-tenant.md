# Migrate the Level Agent Between RMM Tenants (Windows)

## Problem
A tenant-to-tenant migration involved consolidating four separate Level (RMM) tenants. Every endpoint had to leave its old RMM tenant and enroll in the new one, but the only remote channel available to run the swap was the old tenant's own Level terminal. That creates a chicken-and-egg problem: the script has to survive the uninstall of the very agent that delivered it.

## Fix
The wrapper writes the migration script to disk through the RMM terminal, then launches it as a detached hidden PowerShell process. The detached script keeps running after the old agent and its terminal session are gone:

1. Stop and disable Level services and processes.
2. Run the vendor uninstall when `level.exe` is present.
3. Find any remaining Level MSI product codes by decoding the packed (byte-reversed) GUIDs under `HKLM:\SOFTWARE\Classes\Installer\Products` and remove them with `msiexec /x`. This covers installs whose uninstall registry string was blank.
4. Remove leftover identity/config folders. This step is critical for a tenant swap: a stale agent identity re-enrolls the device into the old tenant.
5. Download the MSI and install silently with the new tenant's `LEVEL_API_KEY` property.
6. Re-enable and start the services.

## Safety / Notes
- Every step is logged to `C:\Windows\Temp`, with verbose MSI logs for failure analysis.
- A failed vendor uninstall still falls through to MSI removal rather than aborting the swap.
- The packed-GUID decoding handles the Windows Installer product-code format instead of trusting uninstall strings that were sometimes blank.
- The API key is a placeholder; each device group received its key at run time.

## Result
Endpoints across the four RMM tenants were swapped into the consolidated tenant remotely, without console access to each machine. Uninstall-only variants of these scripts covered endpoints that were leaving RMM management entirely.

## Notes
**Recovered exact source.** Only the tenant API key is a placeholder. The write-to-disk-then-detach delivery is part of the recovered design, not packaging for publication.
