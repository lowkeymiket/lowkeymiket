# Remove Legacy Applications by Display Name

## Problem
During a tenant and endpoint migration, workstations accumulated software that was no longer needed after cutover. The cleanup set included migration agents and legacy applications. Manually removing each product was impractical and inconsistent, especially because the automation needed to run in SYSTEM context through endpoint management.

## Investigation
The production transcript showed the cleanup enumerating installed software from the Windows uninstall registry, identifying the product name, version, publisher, uninstall string and quiet uninstall string. Different installer technologies behaved differently: MSI products returned normal Windows Installer codes while executable uninstallers could return vendor-specific values.

## Fix
The public version searches both 32-bit and 64-bit uninstall registry paths, accepts one or more display-name patterns, prefers a vendor-provided quiet uninstall string, normalizes MSI removals to silent `/qn /norestart`, logs exit codes, and performs a second inventory pass after removal.

## Safety / Notes
- `SupportsShouldProcess` and `-WhatIf` support.
- Targets are explicit display-name patterns rather than blanket software removal.
- Both registry views are checked.
- Every uninstall result is logged.
- Final verification treats still-installed targets as a failure instead of assuming the uninstall command succeeded.

## Result
Recovered execution logs show the migration agent being removed successfully, ShareFile being removed after iterative testing, and final verification correctly identifying software that remained installed. The script re-checks installed state instead of treating an uninstall exit code as proof of success.
