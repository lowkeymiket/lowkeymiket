<#
Reconstructed public version of a real tenant-wide OneNote discovery/audit workflow.
It intentionally treats access-denied, missing OneDrive, and OneNote API limitations as reportable outcomes.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = ".\OneNoteTenantAudit"
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users

Connect-MgGraph -Scopes @('User.Read.All','Sites.Read.All','Notes.Read.All')

$notebooks = [System.Collections.Generic.List[object]]::new()
$errors = [System.Collections.Generic.List[object]]::new()

$users = Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,AccountEnabled
$i = 0
foreach ($user in $users) {
    $i++
    Write-Host "[$i/$($users.Count)] $($user.UserPrincipalName)"

    try {
        $uri = "https://graph.microsoft.com/v1.0/users/$($user.Id)/onenote/notebooks?`$select=id,displayName,createdDateTime,lastModifiedDateTime,isDefault,isShared,userRole,links&`$top=100"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

        foreach ($nb in @($response.value)) {
            $notebooks.Add([pscustomobject]@{
                Scope            = 'User'
                Owner            = $user.UserPrincipalName
                NotebookId       = $nb.id
                DisplayName      = $nb.displayName
                CreatedDateTime  = $nb.createdDateTime
                ModifiedDateTime = $nb.lastModifiedDateTime
                IsDefault        = $nb.isDefault
                IsShared         = $nb.isShared
                UserRole         = $nb.userRole
            })
        }
    }
    catch {
        $errors.Add([pscustomobject]@{
            Scope   = 'User'
            Target  = $user.UserPrincipalName
            Message = $_.Exception.Message
        })
    }
}

$notebooks | Export-Csv (Join-Path $OutputDirectory 'OneNote_Notebooks.csv') -NoTypeInformation -Encoding UTF8
$errors    | Export-Csv (Join-Path $OutputDirectory 'Audit_Errors.csv') -NoTypeInformation -Encoding UTF8

[pscustomobject]@{
    UsersScanned        = $users.Count
    NotebooksDiscovered = $notebooks.Count
    ErrorsRecorded      = $errors.Count
} | Export-Csv (Join-Path $OutputDirectory 'Audit_Summary.csv') -NoTypeInformation -Encoding UTF8

Disconnect-MgGraph | Out-Null
