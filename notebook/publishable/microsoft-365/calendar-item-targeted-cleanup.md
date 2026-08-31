# Targeted Calendar Item Cleanup with Approval Gate

## Problem
An externally organized meeting had been canceled, but a forwarded copy remained on internal calendars. A normal cancellation path was no longer reliable, and deleting calendar items tenant-wide based only on a subject line would have been too risky.

## Fix
The working approach was deliberately split into two stages: first perform read-only discovery and export candidate events for review; then delete only rows explicitly approved. Before deletion, verify multiple event attributes rather than trusting a single field.

The matching model used the mailbox, organizer/sender, subject, start and end time, and the calendar/ICS identifier so that a similarly named legitimate meeting would not be removed accidentally.

## Safety / Notes
- Approval CSV separates discovery from destructive action.
- `ShouldProcess` / `-WhatIf` support.
- Re-reads the event immediately before deletion.
- Refuses deletion if subject, organizer, time boundaries, or `iCalUId` no longer match the reviewed row.
- Logs every delete, refusal, skip, and failure.

## Result
The historical workflow was first used for individual affected mailboxes and then safely expanded using the reviewed approval list.
