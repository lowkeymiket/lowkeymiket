# Safe Tenant-Wide Exchange Calendar Event Removal

## Executive summary

A canceled externally organized meeting remained on internal employee calendars after normal Outlook cancellation behavior failed to remove forwarded copies.

Rather than perform a broad search-and-delete, I designed a multi-stage PowerShell workflow with a **manual approval gate before any destructive operation**.

This is one of the strongest automation examples in this portfolio, not because of what the script could delete, but because of what it **refused to delete automatically**.

## The problem

The organization needed to remove a specific orphaned calendar object across many users' mailboxes. A simplistic approach might be:

```powershell
# BAD IDEA
Get-AllCalendarItems |
    Where-Object Subject -eq "Meeting Name" |
    Remove-CalendarItem
```

That is unsafe. Meeting subjects are not unique.

## Identification strategy

The target event was identified using several properties **together**: sender/organizer, subject, start time, end time, and the ICS/iCalendar UID.

```powershell
$Matches = $CalendarItems | Where-Object {
    $_.Sender  -eq $TargetSender  -and
    $_.Subject -eq $TargetSubject -and
    $_.Start   -eq $TargetStart   -and
    $_.End     -eq $TargetEnd     -and
    $_.ICalUid -eq $TargetICalUid
}
```

Each additional identifier reduces the chance of a false match.

## Phase 1: Discovery only

The first stage deleted nothing. It produced a reviewable artifact instead of changing production state:

```powershell
$Matches |
    Select-Object Mailbox, Sender, Subject, Start, End, ICalUid |
    Export-Csv ".\CalendarCleanup-Review.csv" -NoTypeInformation
```

## Phase 2: Approval

A human could inspect every candidate record:

```
Mailbox | Sender | Subject | Start | End | ICalUid | Approved
```

Only explicitly approved rows moved forward.

## Phase 3: Controlled execution

Only approved records were processed:

```powershell
$Approved = Import-Csv ".\CalendarCleanup-Approved.csv" |
    Where-Object { $_.Approved -eq "Yes" }

foreach ($Item in $Approved) {
    # Locate the exact previously-approved object.
    # Remove only after identifier validation.
}
```

## Rollout strategy

The workflow was tested against specific known users first. Only after successful validation was it expanded tenant-wide:

```
Single mailbox
      |
      v
Several known mailboxes
      |
      v
Review output
      |
      v
Tenant-wide execution
```

## Why the approval CSV matters

It creates a separation between **discovery logic** and **destructive action**. A bug in discovery becomes:

> "This CSV contains the wrong records."

instead of:

> "We just deleted the wrong meetings."

That is a huge difference operationally.

## Reusable automation principle

```
DISCOVER
   |
EXPORT
   |
REVIEW
   |
APPROVE
   |
MODIFY
   |
VERIFY
```

This pattern went on to shape how every other destructive script in the environment was approached.

## Technologies

Exchange Online · Microsoft 365 · PowerShell · calendar/iCalendar metadata · CSV-based approval workflow
