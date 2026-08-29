# Safe Tenant-Wide Exchange Calendar Event Removal

## Executive summary

An organization-wide meeting was rescheduled by its external organizer, but the original invite remained on employee calendars across the tenant because the invite had reached most of the organization through **forwarding**, and forwarded copies never received the update.

This was not routine calendar hygiene. It was a deadline: the stale invites had to be removed **before employees started joining the company-wide call** based on the old, wrong meeting time.

Rather than perform a broad search-and-delete under that pressure, the response was a multi-stage PowerShell workflow with a **manual approval gate before any destructive operation**. The cleanup completed roughly two minutes before the stale invite's start time, with the invites successfully removed org-wide.

The defining feature of the workflow was not what it could delete. It was what it **refused to delete automatically**.

## How the problem was created

The meeting was a Zoom meeting organized externally, by a parent organization. It reached the tenant through a forwarding chain:

```
External organizer (parent organization)
        |
        |  Zoom meeting invite
        v
One internal employee
        |
        |  Forwarded to the wider organization
        v
Hundreds of internal calendars
```

The organizer then **rescheduled** the meeting. That is where the failure mode lives:

- A reschedule or cancellation propagates to the recipients on the **organizer's attendee list**.
- A forwarded invite creates a calendar copy for someone the organizer's system may not track as a direct attendee, especially across an organizational boundary.
- Result: the direct recipient got the update, while the forwarded copies across the tenant kept the **original meeting at the original time**, with a live-looking Zoom link.

Nothing was "broken" in Exchange. Every system behaved as designed. The design just left hundreds of calendars showing a meeting that no longer existed at that time.

### The stakes

Because this was a company-wide call, the failure mode was not "a stale entry on some calendars." It was hundreds of employees showing up to the wrong meeting time, missing the real one, and flooding IT with tickets in the process. The stale copies had to be gone **before the old time slot arrived**, which turned a calendar-data problem into a time-boxed production task.

## The cleanup problem

The organization needed to remove that specific stale calendar object across many users' mailboxes. A simplistic approach might be:

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

Operationally, those are very different failures. One is caught in review; the other is an incident.

It mattered even more here because of the deadline. Time pressure is exactly when skipping the review step is most tempting, and exactly when a bad bulk delete does the most damage. The gate stayed in the workflow even with the clock running.

## Outcome

The cleanup completed roughly **two minutes before the stale invite's scheduled start time**.

- The stale invites were removed org-wide.
- Employees joined the correct, rescheduled call instead of a dead meeting slot.
- No collateral deletions: everything removed had been individually matched on multiple identifiers and explicitly approved.

Two minutes is a thin margin, but it demonstrates the relevant trade-off: the review gate ran inside the deadline rather than costing it. Safety and speed were not in conflict here; they were sequenced.

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
