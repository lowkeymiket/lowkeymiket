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
