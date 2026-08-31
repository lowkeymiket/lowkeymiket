[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$IdentityColumn = 'UserPrincipalName',

    [string]$ResultsPath = '.\ArchiveEnableResults.csv'
)

$ErrorActionPreference = 'Stop'

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
