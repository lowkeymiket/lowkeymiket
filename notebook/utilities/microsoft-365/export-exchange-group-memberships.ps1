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
