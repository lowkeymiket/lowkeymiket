# Exchange Group Membership Export

## Problem
Administrative reviews and migration planning required a single export of who belonged to Exchange-backed groups. The challenge was that Microsoft 365 Groups and traditional distribution/mail-enabled security groups use different Exchange Online cmdlets and return different object shapes.

## Fix
Enumerate traditional Exchange distribution groups with `Get-DistributionGroup` / `Get-DistributionGroupMember`, enumerate Microsoft 365 Groups with `Get-UnifiedGroup` / `Get-UnifiedGroupLinks`, normalize the results, and export one CSV suitable for migration review or access auditing.

## Safety / Notes
- Read-only workflow.
- Uses `-ResultSize Unlimited` so large groups are not silently truncated.
- Captures errors per group instead of aborting an entire tenant export.
- Records group and member recipient types so the CSV remains useful when users, contacts, shared mailboxes, and nested mail-enabled objects coexist.

## Result
This pattern replaced manual group-by-group inspection with a tenant-scale membership inventory that could be filtered, compared, and handed to migration/project teams.

## Notes

The original production code is read-only by design; it only queries and reports.

## Script

```powershell
[CmdletBinding()]
param(
    [string]$OutputPath = ".\ExchangeGroupMemberships.csv"
)

$ErrorActionPreference = 'Stop'
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

$results = [System.Collections.Generic.List[object]]::new()

# Distribution groups and mail-enabled security groups
foreach ($group in Get-DistributionGroup -ResultSize Unlimited) {
    try {
        foreach ($member in Get-DistributionGroupMember -Identity $group.Identity -ResultSize Unlimited -ErrorAction Stop) {
            $results.Add([pscustomobject]@{
                GroupName    = $group.DisplayName
                GroupAddress = $group.PrimarySmtpAddress
                GroupType    = $group.RecipientTypeDetails
                MemberName   = $member.DisplayName
                MemberAddress= $member.PrimarySmtpAddress
                MemberType   = $member.RecipientTypeDetails
                Source       = 'DistributionGroup'
                Status       = 'Success'
            })
        }
    }
    catch {
        $results.Add([pscustomobject]@{
            GroupName=$group.DisplayName; GroupAddress=$group.PrimarySmtpAddress; GroupType=$group.RecipientTypeDetails
            MemberName=$null; MemberAddress=$null; MemberType=$null; Source='DistributionGroup'; Status=$_.Exception.Message
        })
    }
}

# Microsoft 365 Groups
foreach ($group in Get-UnifiedGroup -ResultSize Unlimited) {
    try {
        foreach ($member in Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Members -ResultSize Unlimited -ErrorAction Stop) {
            $results.Add([pscustomobject]@{
                GroupName    = $group.DisplayName
                GroupAddress = $group.PrimarySmtpAddress
                GroupType    = 'Microsoft365Group'
                MemberName   = $member.DisplayName
                MemberAddress= $member.PrimarySmtpAddress
                MemberType   = $member.RecipientTypeDetails
                Source       = 'UnifiedGroup'
                Status       = 'Success'
            })
        }
    }
    catch {
        $results.Add([pscustomobject]@{
            GroupName=$group.DisplayName; GroupAddress=$group.PrimarySmtpAddress; GroupType='Microsoft365Group'
            MemberName=$null; MemberAddress=$null; MemberType=$null; Source='UnifiedGroup'; Status=$_.Exception.Message
        })
    }
}

$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Exported $($results.Count) membership records to $OutputPath"
```
