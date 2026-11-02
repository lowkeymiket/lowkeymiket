# Audit an Entra ID Tenant Read-Only with Microsoft Graph

## Task
A tenant audit asks the same questions every time: users and guests, groups and their members, license seats, directory roles, app registrations and service principals, domains, conditional access, recent sign-ins. The admin center answers one blade at a time and exports little. The account doing the looking is an administrator's, so the audit has to be unable to change what it audits.

## Approach
This work is interactive and needs directory and policy data, so it uses a delegated sign-in. Requesting only `*.Read.All` scopes looked sufficient. It is not: delegated consent for the Graph command-line client accumulates per user, and every new token carries the union of everything ever granted. In the tenant this came from, the token still held write permissions from earlier work.

## Solution
One script, three layers:

1. `Connect-ReadOnlyGraph` requests read scopes only and throws on any scope that is not `*.Read*`. It cannot remove old consent, so it warns about any write scope the token carries. It also stops if the signed-in tenant differs from `-TenantId`, which has no default, because a cached sign-in restores whichever account was used last.
2. `Invoke-GraphGet` is the only caller of `Invoke-MgGraphRequest` and throws on any method but GET. `Get-GraphCollection` pages through it.
3. The operator's rule: a change is stated exactly and confirmed twice, then made by a separate tool.

Thirteen commands, from `me` to `signins`, return flat rows ready for `-OutCsv`.

## Gotchas
- **Pin the module.** Microsoft.Graph.Authentication 2.36.1 failed interactive sign-in with "A window handle must be configured". Version 2.15.0 works, so the script requires exactly that version.
- **Roles cannot be expanded.** `directoryRoles?$expand=members` returned HTTP 500. The script lists the roles, then each role's members: about a hundred active roles, up to a minute.
- **Guest filters are advanced queries.** `userType eq 'Guest'` fails without `ConsistencyLevel: eventual` and `$count=true`, and the header must go out with every page.
- **Version 1.0 conditional access is incomplete.** It omits policies that use preview features; one tenant showed about two thirds of them. The script reads the beta endpoint.
- **`-Top` is one page.** Following `nextLink` would walk the whole sign-in log. Sign-ins also need Entra ID P1, or Graph answers HTTP 403.
- **The GET gate is a guard rail, not a permission boundary.** With write consent on the token, only the gate and the operator's rule stand between a script and a change. Revoking the old consent closes that gap.

## Result
Each command returns flat objects, one per row, and every page of a large collection is followed, so exports are complete and comparable between audits. The role audit is the slow one, a member request per role, at about a minute. Every request is a GET, and leftover write consent shows up as a warning at sign-in. Most of the directory was guest accounts, which is why guests have their own command.

## Script

If you have a similar task, here is a script you can try. The script has no write path. Results include names and sign-in details, so treat the CSV files as sensitive.

```powershell
#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; RequiredVersion='2.15.0' }
<#
.SYNOPSIS
    Read-only audit of an Entra ID tenant through Microsoft Graph.
.DESCRIPTION
    Delegated sign-in that requests *.Read.All scopes only. Every request goes through Invoke-GraphGet, which throws on
    any method other than GET. The token may still carry write permissions consented earlier; the script warns when it does.
    Any change to the tenant is out of scope: make it with a separate tool, after the exact change has been confirmed twice.
.PARAMETER TenantId
    Directory (tenant) ID to sign in to. Mandatory; there is no default, so a cached sign-in cannot pick the tenant.
.PARAMETER Command
    What to read: me, org, users, guests, groups, members, licenses, roles, apps, serviceprincipals, domains, ca, signins.
.PARAMETER Id
    Group ID, for the members command.
.PARAMETER Top
    Number of sign-in log entries to read (one page, 1-1000).
.PARAMETER OutCsv
    Write the rows to this CSV file instead of the console.
.EXAMPLE
    .\Invoke-TenantReadAudit.ps1 -TenantId '<tenant-id>' -Command roles -OutCsv .\roles.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][ValidateSet('me', 'org', 'users', 'guests', 'groups', 'members', 'licenses', 'roles',
        'apps', 'serviceprincipals', 'domains', 'ca', 'signins')][string]$Command,
    [string]$Id,
    [ValidateRange(1, 1000)][int]$Top = 25,
    [string]$OutCsv
)

$ErrorActionPreference = 'Stop'
$v1 = 'https://graph.microsoft.com/v1.0'
$beta = 'https://graph.microsoft.com/beta'
$readScopes = 'User.Read.All', 'Group.Read.All', 'Application.Read.All', 'Directory.Read.All',
    'Organization.Read.All', 'RoleManagement.Read.Directory', 'Policy.Read.All', 'AuditLog.Read.All'
$readPattern = '\.Read(Basic)?(\.All|\.Directory)?$'

# Read scopes only. Consent is cumulative, so the token can still hold write scopes from earlier work: warn about them.
function Connect-ReadOnlyGraph([string]$Tenant, [string[]]$Scopes = $readScopes) {
    $refused = @($Scopes | Where-Object { $_ -notmatch $readPattern })
    if ($refused) { throw "Refusing to request scopes that are not read-only: $($refused -join ', ')" }
    Connect-MgGraph -TenantId $Tenant -Scopes $Scopes -ContextScope Process -NoWelcome | Out-Null
    $context = Get-MgContext
    if (-not $context -or $context.TenantId -ne $Tenant) { throw 'Signed in to a different tenant than requested. Pass the directory (tenant) ID.' }
    $carried = @($context.Scopes | Where-Object { $_ -and $_ -notmatch $readPattern -and $_ -notin 'openid', 'profile', 'email', 'offline_access' })
    if ($carried) { Write-Host "WARNING: The token also carries write-capable scopes from earlier consent: $($carried -join ', '). Only the GET gate keeps this run read-only." }
}

# The only place Invoke-MgGraphRequest is called. -Method exists so the gate can be exercised; anything but GET is refused.
function Invoke-GraphGet([string]$Uri, [hashtable]$Headers, [string]$Method = 'GET') {
    if ($Method -ne 'GET') { throw "WRITE BLOCKED: $Method $Uri. This script only reads." }
    $request = @{ Method = 'GET'; Uri = $Uri; OutputType = 'PSObject' }
    if ($Headers) { $request.Headers = $Headers }
    Invoke-MgGraphRequest @request
}

# Follows @odata.nextLink to the end. The headers go out with every page, not just the first.
function Get-GraphCollection([string]$Uri, [hashtable]$Headers) {
    while ($Uri) {
        $page = Invoke-GraphGet -Uri $Uri -Headers $Headers
        $page.value
        $Uri = $page.'@odata.nextLink'
    }
}

# Advanced queries (userType filter with $count) fail without this header.
$advanced = @{ ConsistencyLevel = 'eventual' }

function Get-AuditRows {
    switch ($Command) {
        'me' {
            Invoke-GraphGet ('{0}/me?$select=id,displayName,userPrincipalName' -f $v1) | Select-Object id, displayName, userPrincipalName
        }
        'org' {
            Get-GraphCollection ('{0}/organization' -f $v1) | Select-Object displayName, tenantType, countryLetterCode, createdDateTime,
                @{ n = 'defaultDomain'; e = { ($_.verifiedDomains | Where-Object isDefault).name } }
        }
        'users' {
            Get-GraphCollection ('{0}/users?$filter=userType eq ''Member''&$count=true&$select=id,displayName,userPrincipalName,accountEnabled,assignedLicenses&$top=999' -f $v1) $advanced |
                Select-Object id, displayName, userPrincipalName, accountEnabled, @{ n = 'licenses'; e = { @($_.assignedLicenses).Count } }
        }
        'guests' {
            Get-GraphCollection ('{0}/users?$filter=userType eq ''Guest''&$count=true&$select=id,displayName,userPrincipalName,accountEnabled,createdDateTime&$top=999' -f $v1) $advanced |
                Select-Object id, displayName, userPrincipalName, accountEnabled, createdDateTime
        }
        'groups' {
            Get-GraphCollection ('{0}/groups?$select=id,displayName,mail,securityEnabled,groupTypes&$top=999' -f $v1) |
                Select-Object id, displayName, mail, securityEnabled,
                    @{ n = 'kind'; e = { if ($_.groupTypes -contains 'Unified') { 'M365' } elseif ($_.securityEnabled) { 'Security' } else { 'Distribution' } } }
        }
        'members' {
            if (-not $Id) { throw 'The members command needs -Id <group-id>.' }
            Get-GraphCollection ('{0}/groups/{1}/members?$select=id,displayName,userPrincipalName' -f $v1, [uri]::EscapeDataString($Id)) |
                Select-Object id, displayName, userPrincipalName, '@odata.type'
        }
        'licenses' {
            Get-GraphCollection ('{0}/subscribedSkus' -f $v1) | Select-Object skuPartNumber, capabilityStatus,
                @{ n = 'enabled'; e = { $_.prepaidUnits.enabled } }, @{ n = 'consumed'; e = { $_.consumedUnits } },
                @{ n = 'free'; e = { $_.prepaidUnits.enabled - $_.consumedUnits } }
        }
        'roles' {
            # $expand=members on directoryRoles returns HTTP 500: list the roles, then the members of each role.
            foreach ($role in Get-GraphCollection ('{0}/directoryRoles' -f $v1)) {
                $members = @(Get-GraphCollection ('{0}/directoryRoles/{1}/members?$select=id,displayName,userPrincipalName' -f $v1, $role.id))
                [pscustomobject]@{
                    role        = $role.displayName
                    memberCount = $members.Count
                    members     = ($members | ForEach-Object { $_.userPrincipalName ?? $_.displayName }) -join '; '
                }
            }
        }
        'apps' {
            Get-GraphCollection ('{0}/applications?$select=id,displayName,appId,signInAudience,createdDateTime&$top=999' -f $v1) |
                Select-Object id, displayName, appId, signInAudience, createdDateTime
        }
        'serviceprincipals' {
            Get-GraphCollection ('{0}/servicePrincipals?$select=id,displayName,appId,servicePrincipalType,accountEnabled&$top=999' -f $v1) |
                Select-Object id, displayName, appId, servicePrincipalType, accountEnabled
        }
        'domains' {
            Get-GraphCollection ('{0}/domains' -f $v1) | Select-Object id, isDefault, isVerified, authenticationType,
                @{ n = 'services'; e = { $_.supportedServices -join ',' } }
        }
        'ca' {
            # v1.0 leaves out policies that use preview features; beta returns them all.
            Get-GraphCollection ('{0}/identity/conditionalAccess/policies' -f $beta) | Select-Object id, displayName, state, createdDateTime, modifiedDateTime
        }
        'signins' {
            # One page on purpose: following nextLink would walk the whole log. Needs Entra ID P1.
            (Invoke-GraphGet ('{0}/auditLogs/signIns?$top={1}' -f $v1, $Top)).value |
                Select-Object createdDateTime, userPrincipalName, appDisplayName, ipAddress,
                    @{ n = 'result'; e = { if ($_.status.errorCode -eq 0) { 'OK' } else { $_.status.failureReason } } }
        }
    }
}

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced for testing: define the functions only

try {
    Connect-ReadOnlyGraph -Tenant $TenantId
    Write-Host 'SUCCESS: Connected to Microsoft Graph (delegated, read scopes requested)'
}
catch { Write-Host "ERROR: Could not connect to Microsoft Graph: $($_.Exception.Message)"; exit 1 }

$exitCode = 0
try {
    $rows = @(Get-AuditRows)
    Write-Host "SUCCESS: $Command returned $($rows.Count) row(s), all read with GET"
    if ($OutCsv) {
        $rows | Export-Csv -LiteralPath $OutCsv -NoTypeInformation -Encoding utf8
        Write-Host "SUCCESS: Results: $OutCsv"
    }
    else { $rows }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
exit $exitCode
```
