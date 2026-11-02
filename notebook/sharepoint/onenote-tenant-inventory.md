# Tenant-Wide OneNote Inventory

## Task
IT needed visibility into OneNote usage across a large Microsoft 365 tenant. There was no simple administrative view that answered where notebooks existed, who owned them, and which user or SharePoint locations could actually be enumerated through Microsoft Graph.

## Approach
The audit attempted discovery across hundreds of users and SharePoint locations. Microsoft Graph returned several materially different failure modes: access denied, users without retrievable OneDrive sites, and the OneNote API's large-library limitation when a document library contained more than 5,000 OneNote objects.

## Solution
The audit was designed as a fault-tolerant discovery job. It enumerates targets, queries the OneNote Graph endpoints, records notebooks that can be resolved, and writes failures to a separate error report so one inaccessible account or site does not stop the tenant-wide run. The notebook, summary, and error exports are separate, and partial results are preserved when Graph cannot enumerate every location.

## Result
The production run discovered **229 notebooks**, resolved **128 packages**, left **101 unresolved**, and recorded **541 errors** while still completing and producing notebook, progress, error, and transcript outputs. The errors documented the boundaries of Graph/OneNote visibility across the tenant.

## Script

If you have a similar task, here is a script you can try. It uses read-only Graph permissions and does not delete, relocate, or modify notebook content.

```powershell
<#
Public version of a real tenant-wide OneNote discovery/audit workflow.
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
```
