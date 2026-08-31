# Export Entra Group Membership with Microsoft Graph

## Problem
A business team needed an authoritative member list for a mail-enabled Entra group. The goal was to export the group's current membership to CSV without hand-copying hundreds of names from the admin center.

## Fix
Query the group by its mail address with Microsoft Graph, resolve its object ID, enumerate all members, normalize useful identity fields, and export the result to CSV.

## Safety / Notes
- Read-only workflow.
- Refuses to continue if the group lookup is missing or ambiguous.
- Uses delegated read scopes only.
- Keeps the group identity in every exported row for traceability.

## Result
The historical run successfully exported the requested group membership to CSV.

## Notes

The original production code is read-only by design; it only queries and reports.

## Script

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GroupMail,

    [string]$OutputPath = '.\GroupMembers.csv'
)

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups
Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All' -NoWelcome

$escaped = $GroupMail.Replace("'", "''")
$groups = @(Get-MgGroup -Filter "mail eq '$escaped'" -Property Id,DisplayName,Mail)

if ($groups.Count -eq 0) { throw "No group found with mail address $GroupMail" }
if ($groups.Count -gt 1) { throw "More than one group matched $GroupMail; refusing ambiguous export." }

$group = $groups[0]
$members = Get-MgGroupMember -GroupId $group.Id -All

$rows = foreach ($member in $members) {
    $p = $member.AdditionalProperties
    [pscustomobject]@{
        GroupDisplayName  = $group.DisplayName
        GroupMail         = $group.Mail
        DisplayName       = $p['displayName']
        UserPrincipalName = $p['userPrincipalName']
        Mail              = $p['mail']
        ObjectType        = $p['@odata.type']
        ObjectId          = $member.Id
    }
}

$rows | Sort-Object DisplayName | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
$rows
```
