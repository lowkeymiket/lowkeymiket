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
