[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$ApprovalCsv,
    [string]$ResultsPath = '.\CalendarCleanupResults.csv'
)

$ErrorActionPreference = 'Stop'
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
