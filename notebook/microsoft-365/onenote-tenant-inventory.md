# Tenant-Wide OneNote Inventory

## Problem
IT needed visibility into OneNote usage across a large Microsoft 365 tenant. There was no simple administrative view that answered where notebooks existed, who owned them, and which user or SharePoint locations could actually be enumerated through Microsoft Graph.

## Investigation
The historical audit attempted discovery across hundreds of users and SharePoint locations. Microsoft Graph returned several materially different failure modes: access denied, users without retrievable OneDrive sites, and the OneNote API's large-library limitation when a document library contained more than 5,000 OneNote objects. Treating all of those as a single fatal error would have made the inventory useless.

## Fix
The audit was designed as a fault-tolerant discovery job. It enumerates targets, queries the OneNote Graph endpoints, records notebooks that can be resolved, and writes failures to a separate error report so one inaccessible account or site does not stop the tenant-wide run.

## Safety / Notes
- Read-only Graph permissions and discovery operations.
- Per-target exception handling.
- Separate notebook, summary, and error exports.
- No deletion, relocation, or modification of notebook content.
- Explicitly preserves partial results when Graph cannot enumerate every location.

## Result
The recovered execution transcript shows the historical job discovered **229 notebooks**, resolved **128 packages**, left **101 unresolved**, and recorded **541 errors** while still completing and producing notebook, progress, error, and transcript outputs. The high error count was useful operational data, not simply a failed run: it documented the boundaries of Graph/OneNote visibility across the tenant.

## Notes
**Reconstructed public version.** The execution transcript is recovered; the exact original source script has not yet been recovered.
