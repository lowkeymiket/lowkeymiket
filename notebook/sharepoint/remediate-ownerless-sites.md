# Remediate Ownerless SharePoint Sites

## Problem

A tenant-wide SharePoint site inventory showed a large number of sites with no listed owner. Ownerless sites create an operational risk: there may be no accountable administrator available to manage access, ownership, lifecycle decisions, or recovery work.

The immediate request was to identify sites whose exported owner fields were blank or whose owner count was zero, then establish a reliable administrative owner without manually opening every site.

## Investigation

The workflow began with a CSV export of SharePoint sites. The ownerless subset was isolated using two independent indicators:

- `Email address of site owners` was blank, **or**
- `Number of site owners` was `0`.

This provided a reviewable target set before making any changes.

## Fix

The remediation used SharePoint Online PowerShell to iterate only the ownerless candidates and assign a designated support/administrative account as a site collection administrator with `Set-SPOUser -IsSiteCollectionAdmin $true`.

A follow-up verification pass queried each target using `Get-SPOSite` and confirmed that the administrative owner was now present.

The public version adds `SupportsShouldProcess`, input validation, a `-WhatIf` path, structured result logging, and optional post-change verification.

## Safety / Notes

- Changes are driven by a reviewed CSV rather than blindly enumerating the tenant.
- Two owner indicators are checked before a site becomes eligible.
- Invalid/missing URLs are skipped.
- `-WhatIf` is supported in the public version.
- Every target receives an independent success/failure result.
- Optional verification queries the resulting site owner after mutation.
- The tenant domain and administrative account are parameterized for publication.

## Result

The recovered execution transcript shows the support account being assigned successfully across a large set of previously ownerless sites. A separate verification command subsequently returned the support account as Owner for the remediated sites.

## Notes

**Recovered production workflow, parameterized and hardened for public release.** The discovery, mutation, and verification command sequences are all preserved in private `raw-recovered/` evidence.

## Script

```powershell
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
```
