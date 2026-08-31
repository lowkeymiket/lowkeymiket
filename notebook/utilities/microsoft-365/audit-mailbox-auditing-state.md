# Tenant Mailbox Auditing Review

## Problem
We needed to verify that mailbox activity would be available for security investigations and administrative review across the tenant, rather than discovering after an incident that individual mailboxes were not in the expected auditing state.

## Fix
Enumerate every Exchange Online mailbox and export its mailbox type and auditing state to CSV. This provides a reviewable baseline before any remediation is performed.

## Safety / Notes
- This public version is intentionally read-only.
- Separates discovery from remediation so an administrator can review exceptions before changing mailbox settings.
- Includes shared/resource mailbox types rather than assuming only user mailboxes matter.
- Modern Exchange Online has tenant-level auditing behavior that must be considered alongside the mailbox-level `AuditEnabled` property; the CSV should therefore be treated as a configuration review rather than proof of every audit event being collected.

## Result
The historical workflow supported tenant-wide auditing verification and bulk administration without opening mailboxes individually in the Microsoft 365 admin interfaces.

## Notes
**Public Reconstruction from historical tenant-wide mailbox auditing work.** Exact original source has not yet been recovered.
