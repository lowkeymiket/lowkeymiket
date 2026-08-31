# Exchange Group Membership Export

## Problem
Administrative reviews and migration planning required a single export of who belonged to Exchange-backed groups. The challenge was that Microsoft 365 Groups and traditional distribution/mail-enabled security groups use different Exchange Online cmdlets and return different object shapes.

## Fix
Enumerate traditional Exchange distribution groups with `Get-DistributionGroup` / `Get-DistributionGroupMember`, enumerate Microsoft 365 Groups with `Get-UnifiedGroup` / `Get-UnifiedGroupLinks`, normalize the results, and export one CSV suitable for migration review or access auditing.

## Safety / Notes
- Read-only workflow.
- Uses `-ResultSize Unlimited` so large groups are not silently truncated.
- Captures errors per group instead of aborting an entire tenant export.
- Records group and member recipient types so the CSV remains useful when users, contacts, shared mailboxes, and nested mail-enabled objects coexist.

## Result
This pattern replaced manual group-by-group inspection with a tenant-scale membership inventory that could be filtered, compared, and handed to migration/project teams.

## Notes
**Public Reconstruction from historical Exchange administration work.** Exact original source has not yet been recovered.
