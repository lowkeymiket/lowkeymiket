# Remediate Ownerless SharePoint Sites

## Problem

A tenant-wide SharePoint site inventory showed a large number of sites with no listed owner. Ownerless sites create an operational risk: there may be no accountable administrator available to manage access, ownership, lifecycle decisions, or recovery work.

The immediate request was to identify sites whose exported owner fields were blank or whose owner count was zero, then establish a reliable administrative owner without manually opening every site.

## Investigation

The workflow began with a CSV export of SharePoint sites. The ownerless subset was isolated using two independent indicators:

- `Email address of site owners` was blank, **or**
- `Number of site owners` was `0`.

This provided a reviewable target set before making any changes.

## Fix

The remediation used SharePoint Online PowerShell to iterate only the ownerless candidates and assign a designated support/administrative account as a site collection administrator with `Set-SPOUser -IsSiteCollectionAdmin $true`.

A follow-up verification pass queried each target using `Get-SPOSite` and confirmed that the administrative owner was now present.

The public version adds `SupportsShouldProcess`, input validation, a `-WhatIf` path, structured result logging, and optional post-change verification.

## Safety / Notes

- Changes are driven by a reviewed CSV rather than blindly enumerating the tenant.
- Two owner indicators are checked before a site becomes eligible.
- Invalid/missing URLs are skipped.
- `-WhatIf` is supported in the public version.
- Every target receives an independent success/failure result.
- Optional verification queries the resulting site owner after mutation.
- The tenant domain and administrative account are parameterized for publication.

## Result

The recovered execution transcript shows the support account being assigned successfully across a large set of previously ownerless sites. A separate verification command subsequently returned the support account as Owner for the remediated sites.

## Notes

**Recovered production workflow, parameterized and hardened for public release.** The discovery, mutation, and verification command sequences are all preserved in private `raw-recovered/` evidence.
