# Microsoft 365 Tenant Consolidation and Endpoint Cutover

## Problem
Multiple business entities needed to be consolidated into a common Microsoft 365 environment without leaving users with broken Outlook profiles, stale OneDrive sync relationships, incorrect Office licensing, or unmanaged endpoint leftovers after identity cutover.

## Scope
The work crossed identity, Exchange Online, OneDrive, desktop application state, device registration, endpoint deployment, licensing and end-user communications. The cutover workflow had to account for computers that were offline during deployment and users who might have Outlook or OneDrive running when profile changes were applied.

## Fix
Quest On Demand Migration was used for the migration platform while custom operational work handled the surrounding endpoint lifecycle. The Desktop Update Agent workflow updated Microsoft 365 application licensing, remediated Outlook, transitioned OneDrive to the target tenant, and instructed users how to reuse the existing local OneDrive folder safely. Deployment was designed so an offline device would receive the prompt after it came back online rather than missing the cutover permanently.

Separate cleanup automation removed migration agents and legacy applications after cutover and then verified the endpoint state. Device-registration diagnostics were also used to confirm that target systems were Microsoft Entra joined and authenticated to the expected tenant.

## Safety / Notes
- User-facing cutover documentation was written before deployment.
- Offline-device behavior was explicitly planned.
- Outlook and OneDrive process state was handled during transition.
- Existing OneDrive folders were reused rather than blindly creating duplicate local data trees.
- Post-migration cleanup scripts verified removal rather than trusting installer exit codes.
- Vendor-proprietary scripts and migration internals are intentionally excluded from this repository.

## Result
Mail, OneDrive data, licensing, endpoint state, and user access moved to the target tenant together. Devices that were offline during the deployment window completed the cutover after reconnecting instead of being missed.
