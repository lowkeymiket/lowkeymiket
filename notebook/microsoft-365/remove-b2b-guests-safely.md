# Entra B2B Guest Removal

## Task
Administrators needed a repeatable way to remove external B2B guest accounts without risking deletion of normal member accounts or unrelated identities.

## Solution
The script resolves candidate users through Microsoft Graph and applies multiple identity checks before deletion. It requires the Entra object to be a `Guest` and its UPN to match the expected B2B `#EXT#` pattern. It supports preview and review before destructive action, and it logs skipped and deleted objects separately.

## Script

If you have a similar task, here is a script you can try. The script is dry-run as published: it reports each change and makes none. It asks for `User.ReadWrite.All` at sign-in, even on a dry run.

```powershell
<# Public version. Deliberately requires both Guest userType and #EXT# UPN marker. #>
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
