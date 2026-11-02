# Atomic Microsoft 365 License Migration

## Task
A large group of users needed to move from one Microsoft 365 license SKU to another without temporarily losing services such as Office, Exchange, or other overlapping service plans. A small pilot had to be validated before running the full batch.

## Solution
The migration pattern adds the destination license first, verifies the assignment, and only then removes the source license, so there is no licensing gap. SKU availability is checked before migration. CSV input makes the operation repeatable and allows the pilot and the full batch to use the same logic, and per-user success/failure results are written to CSV.

## Result
The pilot migration completed successfully and was spot-checked in the Microsoft 365 Admin Center before proceeding to the full batch.

## Script

If you have a similar task, here is a script you can try. The script is dry-run as published: it reports each change and makes none. It asks for `Directory.ReadWrite.All` at sign-in, even on a dry run.

```powershell
<# Public version of an operational pattern used to move users between M365 SKUs.
   Adds the destination license first, verifies assignment, then removes the source license. #>
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [Parameter(Mandatory)] [string]$SourceSkuPartNumber,
    [Parameter(Mandatory)] [string]$DestinationSkuPartNumber,
    [string]$OutputCsv = '.\LicenseMigrationResults.csv',
    [switch]$WhatIf
)

# Read-only for publication: WhatIf is forced on; no changes are made.
$WhatIf = $true

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
```
