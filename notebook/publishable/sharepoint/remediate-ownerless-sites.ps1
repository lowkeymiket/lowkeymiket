<#+
.SYNOPSIS
Adds a designated site collection administrator to SharePoint Online sites identified as ownerless in a reviewed CSV export.

.DESCRIPTION
Public, parameterized version reconstructed from a recovered production console session.
The historical workflow first filtered an administrative CSV for sites with zero/blank owners,
then assigned a support account as site collection administrator and verified the resulting Owner value.

This version adds ShouldProcess, validation, structured results, and an optional verification pass.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter(Mandatory)]
    [string]$SiteCollectionAdmin,

    [string]$ResultsPath = '.\OwnerlessSiteRemediationResults.csv',

    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
# Assumes an existing SharePoint Online admin session (Connect-SPOService).

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$rows = Import-Csv -LiteralPath $CsvPath
$requiredColumns = @('URL', 'Number of site owners', 'Email address of site owners')
$missing = $requiredColumns | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missing) {
    throw "CSV is missing required column(s): $($missing -join ', ')"
}

$sites = $rows | Where-Object {
    [string]::IsNullOrWhiteSpace($_.'Email address of site owners') -or
    $_.'Number of site owners' -eq '0'
}

Write-Host "Ownerless candidates: $($sites.Count)" -ForegroundColor Cyan
$results = [System.Collections.Generic.List[object]]::new()

foreach ($site in $sites) {
    $url = $site.URL

    if ([string]::IsNullOrWhiteSpace($url) -or $url -notmatch '^https://') {
        $results.Add([pscustomobject]@{
            Url = $url
            Status = 'Skipped'
            VerifiedOwner = $null
            Notes = 'Missing or invalid HTTPS site URL'
        })
        continue
    }

    try {
        if ($PSCmdlet.ShouldProcess($url, "Assign $SiteCollectionAdmin as site collection administrator")) {
            Set-SPOUser -Site $url -LoginName $SiteCollectionAdmin -IsSiteCollectionAdmin $true
        }

        $verifiedOwner = $null
        if ($Verify -and -not $WhatIfPreference) {
            $verifiedOwner = (Get-SPOSite -Identity $url).Owner
        }

        $results.Add([pscustomobject]@{
            Url = $url
            Status = if ($WhatIfPreference) { 'WouldUpdate' } else { 'Updated' }
            VerifiedOwner = $verifiedOwner
            Notes = $null
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            Url = $url
            Status = 'Failed'
            VerifiedOwner = $null
            Notes = $_.Exception.Message
        })
    }
}

$results | Export-Csv -LiteralPath $ResultsPath -NoTypeInformation
$results | Group-Object Status | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Results: $ResultsPath"
