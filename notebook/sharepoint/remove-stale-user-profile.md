# Remove a Stale SharePoint User Identity

## Problem
A rehired employee had a current Entra ID account, but SharePoint still retained the legacy identity from the employee's previous account. The stale entry appeared as an inactive user and could trigger duplicate-account behavior because the legacy and current identities shared the same email address.

## Fix
A PnP PowerShell workflow connects to each affected SharePoint or OneDrive site, removes the stale membership identity, then queries the site's User Information List to verify that the legacy entry is gone.

## Safety / Notes
- Operates only against a reviewed list of affected sites.
- Targets the exact SharePoint membership login rather than a fuzzy display-name match.
- Performs a post-removal verification query.
- Records a result for every site, including failures, instead of silently continuing.

## Result
The stale identity was removed from affected sites while the active Entra account remained intact, resolving the legacy-account conflict.

## Notes
**Recovered from the production console session and parameterized for publication.** Organization domains, names, app IDs, and paths were removed.

## Publication note

The script below is published in read-only mode: a guard at the top stops execution before any change is made. It is included to document the approach, for educational purposes.

## Script

```powershell
param(
    [Parameter(Mandatory)] [string]$SitesCsv,
    [Parameter(Mandatory)] [string]$LoginName,
    [Parameter(Mandatory)] [string]$ExpectedDisplayName,
    [Parameter(Mandatory)] [string]$ExpectedEmail,
    [Parameter(Mandatory)] [string]$ClientId,
    [string]$OutputCsv = '.\SharePointUserCleanupResults.csv'
)

# Read-only for publication: this guard stops the script before any
# change is made. The rest is preserved to document the approach.
$ReadOnly = $true
if ($ReadOnly) {
    Write-Output 'READ-ONLY published copy; execution disabled.'
    exit 0
}

$results = @()
$csv = Import-Csv $SitesCsv

foreach ($row in $csv) {
    Write-Host "Processing $($row.Site)" -ForegroundColor Cyan
    try {
        Connect-PnPOnline -Url $row.Site -Interactive -ClientId $ClientId
        Remove-PnPUser -Identity $LoginName -Force
        Start-Sleep -Seconds 1

        $verify = Get-PnPListItem -List 'User Information List' -Fields 'ID','Title','EMail' |
            Where-Object {
                $_['Title'] -eq $ExpectedDisplayName -and
                $_['EMail'] -eq $ExpectedEmail
            }

        $status = if ($verify) { 'Still Exists' } else { 'Removed' }
        $results += [pscustomobject]@{ Site = $row.Site; Status = $status }
        Write-Host "$($row.Site) - $status" -ForegroundColor Green
    }
    catch {
        $results += [pscustomobject]@{ Site = $row.Site; Status = $_.Exception.Message }
        Write-Host "$($row.Site) - FAILED" -ForegroundColor Red
    }
}

$results | Export-Csv -Path $OutputCsv -NoTypeInformation
```
