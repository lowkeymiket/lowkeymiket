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

## Notes

The original production code has been modified to run read-only for this public notebook.

## Script

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$ApprovalCsv,
    [string]$ResultsPath = '.\CalendarCleanupResults.csv'
)

$ErrorActionPreference = 'Stop'

# Read-only for publication: WhatIf is forced on, so every change is
# simulated and logged instead of executed.
$WhatIfPreference = $true
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Calendar
Connect-MgGraph -Scopes 'Calendars.ReadWrite' -NoWelcome

$approved = Import-Csv -LiteralPath $ApprovalCsv
$results = foreach ($row in $approved) {
    if ($row.Approved -notmatch '^(?i:true|yes|y|1)$') { continue }

    $userId = $row.UserPrincipalName
    $eventId = $row.EventId
    if ([string]::IsNullOrWhiteSpace($userId) -or [string]::IsNullOrWhiteSpace($eventId)) {
        [pscustomobject]@{ User=$userId; EventId=$eventId; Status='Skipped'; Notes='Missing user or event ID' }
        continue
    }

    try {
        $event = Get-MgUserEvent -UserId $userId -EventId $eventId -Property 'id,subject,start,end,iCalUId,organizer' -ErrorAction Stop

        $mismatch = @()
        if ($row.Subject -and $event.Subject -ne $row.Subject) { $mismatch += 'Subject' }
        if ($row.ICalUId -and $event.ICalUId -ne $row.ICalUId) { $mismatch += 'ICalUId' }
        if ($row.StartDateTime -and $event.Start.DateTime -ne $row.StartDateTime) { $mismatch += 'StartDateTime' }
        if ($row.EndDateTime -and $event.End.DateTime -ne $row.EndDateTime) { $mismatch += 'EndDateTime' }
        if ($row.OrganizerAddress -and $event.Organizer.EmailAddress.Address -ne $row.OrganizerAddress) { $mismatch += 'OrganizerAddress' }

        if ($mismatch.Count -gt 0) {
            [pscustomobject]@{ User=$userId; EventId=$eventId; Status='Refused'; Notes="Verification mismatch: $($mismatch -join ', ')" }
            continue
        }

        if ($PSCmdlet.ShouldProcess("$userId / $($event.Subject)", 'Delete verified calendar item')) {
            Remove-MgUserEvent -UserId $userId -EventId $eventId -Confirm:$false -ErrorAction Stop
            [pscustomobject]@{ User=$userId; EventId=$eventId; Status='Deleted'; Notes='' }
        } else {
            [pscustomobject]@{ User=$userId; EventId=$eventId; Status='WouldDelete'; Notes='WhatIf/confirmation prevented change' }
        }
    }
    catch {
        [pscustomobject]@{ User=$userId; EventId=$eventId; Status='Failed'; Notes=$_.Exception.Message }
    }
}

$results | Export-Csv -LiteralPath $ResultsPath -NoTypeInformation
$results
```
