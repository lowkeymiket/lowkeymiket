# Enable Exchange Online Archive Mailboxes from CSV

## Problem
A migration/licensing workflow identified mailboxes that needed online archives enabled. Doing this manually in the Microsoft 365 admin interfaces was slow and error-prone, especially when the target list already existed in CSV form.

## Fix
Use Exchange Online PowerShell to import a reviewed CSV, inspect each mailbox's current archive state, enable the archive only when needed, and export a per-user result log.

## Safety / Notes
- Supports `-WhatIf` through `ShouldProcess`.
- Skips blank identities.
- Checks whether the archive is already active before making a change.
- Re-queries the mailbox after the operation to verify state.
- Captures failures per mailbox rather than terminating the batch.

## Result
The historical workflow produced a working CSV-driven archive-enablement template for Exchange Online administration. The public version here is hardened and sanitized.

## Publication note

The script below is published in read-only mode: WhatIf/dry-run is forced on, so it simulates and logs the changes it would make without making them. It is included to document the approach, for educational purposes.

## Script

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
