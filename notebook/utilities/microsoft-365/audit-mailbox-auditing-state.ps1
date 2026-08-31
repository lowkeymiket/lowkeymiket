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
