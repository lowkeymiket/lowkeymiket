# Tenant Mailbox Auditing Review

## Task
We needed to verify that mailbox activity would be available for security investigations and administrative review across the tenant, rather than discovering after an incident that individual mailboxes were not in the expected auditing state.

## Solution
Enumerate every Exchange Online mailbox, shared and resource mailboxes included, and export its mailbox type and auditing state to CSV. This provides a reviewable baseline before any remediation is performed.

Modern Exchange Online has tenant-level auditing behavior that must be considered alongside the mailbox-level `AuditEnabled` property, so the CSV should be treated as a configuration review rather than proof of every audit event being collected.

## Result
The workflow supported tenant-wide auditing verification and bulk administration without opening mailboxes individually in the Microsoft 365 admin interfaces.

## Script
If you have a similar task, here is a script you can try. It is read-only.

```powershell
[CmdletBinding()]
param(
    [string]$OutputPath = ".\MailboxAuditingState.csv"
)

$ErrorActionPreference = 'Stop'
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

$rows = foreach ($mailbox in Get-EXOMailbox -ResultSize Unlimited -Properties AuditEnabled,RecipientTypeDetails) {
    [pscustomobject]@{
        DisplayName          = $mailbox.DisplayName
        UserPrincipalName    = $mailbox.UserPrincipalName
        PrimarySmtpAddress   = $mailbox.PrimarySmtpAddress
        RecipientTypeDetails = $mailbox.RecipientTypeDetails
        AuditEnabled         = $mailbox.AuditEnabled
    }
}

$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
Disconnect-ExchangeOnline -Confirm:$false

$disabled = @($rows | Where-Object AuditEnabled -eq $false)
Write-Host "Mailboxes inspected: $($rows.Count)"
Write-Host "Mailboxes reporting AuditEnabled=False: $($disabled.Count)"
```
