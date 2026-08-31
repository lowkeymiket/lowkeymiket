# Distribution List Last-Used Audit

## Problem
The tenant had accumulated a large number of distribution lists and the business needed a defensible way to decide which could be retired. Creation date and membership did not answer the important question: had the address actually received mail recently?

## Investigation
The historical workflow enumerated Exchange Online distribution groups and queried `Get-MessageTraceV2` for each address. Recovered execution evidence shows the run progressing through named lists and then repeatedly hitting Exchange Online's "recent queries have surpassed the permitted limit" response. That failure became part of the design problem, not just an incidental error.

## Fix
The public reconstruction enumerates distribution groups, applies configurable naming exclusions, breaks the lookback period into smaller trace windows, retries likely throttling responses with exponential backoff, records the newest observed message date, and exports a review CSV with a blank `ReviewDecision` column.

## Safety / Notes
- Read-only discovery. The script never deletes groups.
- Configurable naming exclusions protect known classes of lists from review.
- Human approval is separated from discovery through the exported `ReviewDecision` field.
- Date-range chunking reduces query size.
- Exponential retry/backoff handles Exchange Online trace throttling more gracefully.
- Per-group errors are recorded without aborting the entire tenant audit.
- The script records both the latest observed message and the number of messages returned during the audit window.

## Result
The historical run produced the basis for a Keep/Delete business review and exposed a real tenant-scale constraint: a straightforward loop of `Get-MessageTraceV2` calls can exceed service query limits. The hardened public version incorporates that lesson directly.

## Notes
**Reconstructed public version from recovered execution evidence.** The original source file was not recovered, so this is intentionally not represented as exact historical code.
