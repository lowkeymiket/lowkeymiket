<# Public reconstruction. Deliberately requires both Guest userType and #EXT# UPN marker. #>
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [string]$OutputCsv = '.\GuestRemovalResults.csv',
    [switch]$WhatIf
)
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
