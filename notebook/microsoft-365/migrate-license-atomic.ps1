<# Public reconstruction of an operational pattern used to move users between M365 SKUs.
   Adds the destination license first, verifies assignment, then removes the source license. #>
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [Parameter(Mandatory)] [string]$SourceSkuPartNumber,
    [Parameter(Mandatory)] [string]$DestinationSkuPartNumber,
    [string]$OutputCsv = '.\LicenseMigrationResults.csv',
    [switch]$WhatIf
)

Connect-MgGraph -Scopes 'User.Read.All','Directory.ReadWrite.All'
$skus = Get-MgSubscribedSku
$source = $skus | Where-Object SkuPartNumber -eq $SourceSkuPartNumber
$dest   = $skus | Where-Object SkuPartNumber -eq $DestinationSkuPartNumber
if (-not $source -or -not $dest) { throw 'Source or destination SKU not found.' }

$results = foreach ($row in (Import-Csv $CsvPath)) {
    $upn = $row.UserPrincipalName
    try {
        $user = Get-MgUser -UserId $upn -Property Id,UserPrincipalName,AssignedLicenses
        if ($WhatIf) {
            [pscustomobject]@{ User=$upn; Status='WouldMigrate'; Detail="$SourceSkuPartNumber -> $DestinationSkuPartNumber" }
            continue
        }

        Set-MgUserLicense -UserId $user.Id -AddLicenses @(@{SkuId=$dest.SkuId}) -RemoveLicenses @()
        $check = Get-MgUser -UserId $user.Id -Property AssignedLicenses
        if ($check.AssignedLicenses.SkuId -notcontains $dest.SkuId) { throw 'Destination SKU did not verify after assignment.' }

        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($source.SkuId)
        [pscustomobject]@{ User=$upn; Status='Migrated'; Detail="$SourceSkuPartNumber -> $DestinationSkuPartNumber" }
    }
    catch {
        [pscustomobject]@{ User=$upn; Status='Error'; Detail=$_.Exception.Message }
    }
}
$results | Export-Csv $OutputCsv -NoTypeInformation
