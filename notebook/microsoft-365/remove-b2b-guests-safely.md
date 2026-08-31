# Safe Entra B2B Guest Removal

## Problem
Administrators needed a repeatable way to remove external B2B guest accounts without risking deletion of normal member accounts or unrelated identities.

## Fix
The script resolves candidate users through Microsoft Graph and applies multiple identity checks before deletion.

## Safety / Notes
- Requires the Entra object to be a `Guest`.
- Requires the expected B2B `#EXT#` UPN pattern.
- Supports preview/review before destructive action.
- Logs skipped and deleted objects separately.

## Result
The workflow provides a safer template for bulk guest cleanup than directly piping search results into `Remove-MgUser`.

## Notes
**Reconstructed public version** from the production-safe workflow we used. Exact historical source was not recovered.
