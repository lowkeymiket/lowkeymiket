# Export Full Exchange Mailbox Properties for Troubleshooting

## Problem
A mailbox/object discrepancy needed deeper troubleshooting than the admin center exposed. We needed the complete Exchange recipient object, including archive, addressing, policy, move, and directory-backed attributes, in a form that could be compared or shared for analysis.

## Fix
Connect to Exchange Online, retrieve the target mailbox, export every returned property to CSV, and print the full object for immediate inspection.

## Gotchas
First confirm the Exchange Online cmdlets are actually loaded, then determine whether the target resolves as an Exchange mailbox. A missing cmdlet and a missing Exchange recipient are different failures and should not be treated as the same problem.

## Script
If you have a similar problem, here is a script you can try. It is read-only and takes the mailbox identity and destination path as parameters.

```powershell
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
```
