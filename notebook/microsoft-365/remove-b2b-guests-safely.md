# Safe Entra B2B Guest Removal

## Problem
Administrators needed a repeatable way to remove external B2B guest accounts without risking deletion of normal member accounts or unrelated identities.

## Fix
The script resolves candidate users through Microsoft Graph and applies multiple identity checks before deletion.

## Safety / Notes
- Requires the Entra object to be a `Guest`.
- Requires the expected B2B `#EXT#` UPN pattern.
- Supports preview/review before destructive action.
- Logs skipped and deleted objects separately.

## Result
The workflow provides a safer template for bulk guest cleanup than directly piping search results into `Remove-MgUser`.

## Notes
**Reconstructed public version** from the production-safe workflow we used. Exact historical source was not recovered.

## Publication note

The script below is published in read-only mode: WhatIf/dry-run is forced on, so it simulates and logs the changes it would make without making them. It is included to document the approach, for educational purposes.

## Script

```powershell
<# Public reconstruction. Deliberately requires both Guest userType and #EXT# UPN marker. #>
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [string]$OutputCsv = '.\GuestRemovalResults.csv',
    [switch]$WhatIf
)

# Read-only for publication: WhatIf is forced on; no changes are made.
$WhatIf = $true
Connect-MgGraph -Scopes 'User.ReadWrite.All'
$results = foreach ($row in (Import-Csv $CsvPath)) {
    $upn = $row.UserPrincipalName
    try {
        $user = Get-MgUser -UserId $upn -Property Id,UserPrincipalName,UserType,DisplayName
        if ($user.UserType -ne 'Guest' -or $user.UserPrincipalName -notmatch '#EXT#') {
            [pscustomobject]@{ User=$upn; Status='Skipped'; Detail='Safety check failed: not an external guest account.' }
            continue
        }
        if ($WhatIf) {
            [pscustomobject]@{ User=$upn; Status='WouldRemove'; Detail=$user.DisplayName }
            continue
        }
        Remove-MgUser -UserId $user.Id
        [pscustomobject]@{ User=$upn; Status='Removed'; Detail=$user.DisplayName }
    }
    catch { [pscustomobject]@{ User=$upn; Status='Error'; Detail=$_.Exception.Message } }
}
$results | Export-Csv $OutputCsv -NoTypeInformation
```
