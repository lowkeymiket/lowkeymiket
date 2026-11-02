# Enable Exchange Online Archive Mailboxes from CSV

## Task
A migration/licensing workflow identified mailboxes that needed online archives enabled. Doing this manually in the Microsoft 365 admin interfaces was slow and error-prone, especially when the target list already existed in CSV form.

## Solution
Use Exchange Online PowerShell to import a reviewed CSV, skip blank identities, inspect each mailbox's current archive state, enable the archive only when it is not already active, re-query the mailbox to verify state, and export a per-user result log. Failures are captured per mailbox rather than terminating the batch. The script supports `-WhatIf` through `ShouldProcess`.

## Result
The workflow produced a working CSV-driven archive-enablement template for Exchange Online administration.

## Script
If you have a similar task, here is a script you can try. The script is dry-run as published: it reports each change on screen and makes none.

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$IdentityColumn = 'UserPrincipalName',

    [string]$ResultsPath = '.\ArchiveEnableResults.csv'
)

$ErrorActionPreference = 'Stop'

# Read-only for publication: WhatIf is forced on, so every change is
# simulated and logged instead of executed.
$WhatIfPreference = $true

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) {
    throw 'ExchangeOnlineManagement module is required.'
}

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

$results = foreach ($row in (Import-Csv -LiteralPath $CsvPath)) {
    $identity = $row.$IdentityColumn

    if ([string]::IsNullOrWhiteSpace($identity)) {
        [pscustomobject]@{ Identity=$identity; Before='Unknown'; After='Unknown'; Status='Skipped'; Notes='Missing identity' }
        continue
    }

    try {
        $before = Get-Mailbox -Identity $identity -ErrorAction Stop
        if ($before.ArchiveStatus -eq 'Active') {
            [pscustomobject]@{ Identity=$identity; Before='Active'; After='Active'; Status='NoChange'; Notes='Archive already enabled' }
            continue
        }

        if ($PSCmdlet.ShouldProcess($identity, 'Enable Exchange Online archive mailbox')) {
            Enable-Mailbox -Identity $identity -Archive -ErrorAction Stop
            Start-Sleep -Seconds 2
            $after = Get-Mailbox -Identity $identity -ErrorAction Stop
            [pscustomobject]@{ Identity=$identity; Before=$before.ArchiveStatus; After=$after.ArchiveStatus; Status='Updated'; Notes='' }
        }
        else {
            [pscustomobject]@{ Identity=$identity; Before=$before.ArchiveStatus; After=$before.ArchiveStatus; Status='WouldUpdate'; Notes='WhatIf/confirmation prevented change' }
        }
    }
    catch {
        [pscustomobject]@{ Identity=$identity; Before='Unknown'; After='Unknown'; Status='Failed'; Notes=$_.Exception.Message }
    }
}

$results | Export-Csv -LiteralPath $ResultsPath -NoTypeInformation
$results
Disconnect-ExchangeOnline -Confirm:$false
```
