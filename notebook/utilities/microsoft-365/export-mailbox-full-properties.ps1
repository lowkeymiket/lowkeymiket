[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$MailboxIdentity,

    [string]$OutputPath = '.\MailboxProperties.csv'
)

$ErrorActionPreference = 'Stop'
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

try {
    $mailbox = Get-Mailbox -Identity $MailboxIdentity -ErrorAction Stop
    $mailbox | Select-Object * | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
    $mailbox | Format-List *
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false
}
