param(
    [Parameter(Mandatory)] [string]$SitesCsv,
    [Parameter(Mandatory)] [string]$LoginName,
    [Parameter(Mandatory)] [string]$ExpectedDisplayName,
    [Parameter(Mandatory)] [string]$ExpectedEmail,
    [Parameter(Mandatory)] [string]$ClientId,
    [string]$OutputCsv = '.\SharePointUserCleanupResults.csv'
)

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
