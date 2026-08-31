# Export Entra Group Membership with Microsoft Graph

## Problem
A business team needed an authoritative member list for a mail-enabled Entra group. The goal was to export the group's current membership to CSV without hand-copying hundreds of names from the admin center.

## Fix
Query the group by its mail address with Microsoft Graph, resolve its object ID, enumerate all members, normalize useful identity fields, and export the result to CSV.

## Safety / Notes
- Read-only workflow.
- Refuses to continue if the group lookup is missing or ambiguous.
- Uses delegated read scopes only.
- Keeps the group identity in every exported row for traceability.

## Result
The historical run successfully exported the requested group membership to CSV.
