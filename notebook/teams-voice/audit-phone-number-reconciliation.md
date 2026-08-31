# Teams Voice Phone Number Reconciliation

## Problem

The source employee directory and the Microsoft Teams Phone assignment state had drifted apart. Some employees expected to have Teams Voice had no number in the source data, some had a number in the source but no matching Teams assignment, and others had conflicting phone values.

Manually checking more than a hundred voice-enabled users across HR data and Teams administration was slow and error-prone.

## Investigation

The historical audit produced a merge log that classified records into categories such as:

- Filled blank
- Updated existing value
- Already matched
- Phone not assigned in Teams
- User not found in Teams assignments
- No phone in source

The important design choice was to preserve the original and proposed values instead of silently overwriting contact data.

## Fix

This public version accepts two CSV exports:

1. The authoritative employee/source directory.
2. The current Teams Phone assignment export.

It normalizes phone numbers and display names, compares the two datasets, and generates a reconciliation report identifying matches, missing assignments, missing source values, and mismatches.

The output includes a `SuggestedPhone` field, but the script deliberately performs **no live Teams mutations**.

## Safety / Notes

- Read-only against Microsoft 365.
- Does not assign or remove phone numbers.
- Preserves both source and Teams values for human review.
- Normalizes common North American phone formats before comparing them.
- Flags every non-matching record for review.
- Separates data reconciliation from production change execution.

## Result

The historical workflow created a traceable merge log showing which users required corrections, which values were filled from the authoritative source, and which records already matched. This converted a messy telephony-data cleanup into a reviewable change set rather than a blind bulk update.

## Notes

The original production code is read-only by design; it only queries and reports.

## Script

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceCsv,

    [Parameter(Mandatory)]
    [string]$TeamsCsv,

    [string]$OutputCsv = ".\TeamsVoice-Reconciliation.csv",

    [string]$VoiceFlagColumn = "TeamsVoiceEnabled",
    [string]$SourcePhoneColumn = "Work Contact: Work Phone",
    [string]$FirstNameColumn = "Legal First Name",
    [string]$LastNameColumn = "Legal Last Name",
    [string]$TeamsNameColumn = "DisplayName",
    [string]$TeamsPhoneColumn = "TelephoneNumber"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Phone {
    param([AllowNull()][string]$Phone)

    if ([string]::IsNullOrWhiteSpace($Phone)) { return $null }
    $digits = ($Phone -replace '\D', '')

    if ($digits.Length -eq 10) { return "+1$digits" }
    if ($digits.Length -eq 11 -and $digits.StartsWith('1')) { return "+$digits" }
    if ($Phone.Trim().StartsWith('+')) { return '+' + $digits }
    return $digits
}

function Normalize-Name {
    param([AllowNull()][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    return (($Name.Trim() -replace '\s+', ' ').ToLowerInvariant())
}

$source = Import-Csv -LiteralPath $SourceCsv
$teams  = Import-Csv -LiteralPath $TeamsCsv

$teamsIndex = @{}
foreach ($row in $teams) {
    $key = Normalize-Name $row.$TeamsNameColumn
    if ($key -and -not $teamsIndex.ContainsKey($key)) {
        $teamsIndex[$key] = $row
    }
}

$results = foreach ($row in $source) {
    if ($VoiceFlagColumn -and $row.$VoiceFlagColumn -notmatch '^(?i:y|yes|true|1)$') {
        continue
    }

    $displayName = ("{0} {1}" -f $row.$FirstNameColumn, $row.$LastNameColumn).Trim()
    $nameKey = Normalize-Name $displayName
    $sourcePhone = Normalize-Phone $row.$SourcePhoneColumn
    $teamsRow = if ($nameKey -and $teamsIndex.ContainsKey($nameKey)) { $teamsIndex[$nameKey] } else { $null }
    $teamsPhone = if ($teamsRow) { Normalize-Phone $teamsRow.$TeamsPhoneColumn } else { $null }

    $status = switch ($true) {
        (-not $teamsRow) { 'User not found in Teams assignments'; break }
        ([string]::IsNullOrWhiteSpace($sourcePhone)) { 'No phone in source'; break }
        ([string]::IsNullOrWhiteSpace($teamsPhone)) { 'Phone not assigned in Teams'; break }
        ($sourcePhone -eq $teamsPhone) { 'Already matched'; break }
        default { 'Phone mismatch' }
    }

    [pscustomobject]@{
        DisplayName       = $displayName
        SourcePhone       = $sourcePhone
        TeamsPhone        = $teamsPhone
        Status            = $status
        SuggestedPhone    = if ($sourcePhone -and $sourcePhone -ne $teamsPhone) { $sourcePhone } else { $null }
        RequiresReview    = $status -ne 'Already matched'
    }
}

$results | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8
$results | Group-Object Status | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Reconciliation exported to $OutputCsv"
```
