<#
Reconstructed public version of a real Exchange Online distribution-list usage audit.
The historical workflow used Get-MessageTraceV2 and produced a reviewable keep/delete report.
Tenant-specific names, domains, dates, and exclusions have been parameterized.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,365)]
    [int]$LookbackDays = 30,
    [ValidateRange(1,10)]
    [int]$ChunkDays = 10,
    [string]$OutputPath = ".\distribution-list-usage.csv",
    [string[]]$ExcludeNamePrefix = @(),
    [ValidateRange(0,10)]
    [int]$MaxRetries = 4,
    [ValidateRange(0,60000)]
    [int]$DelayMilliseconds = 750
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) {
    throw 'ExchangeOnlineManagement is required.'
}

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

function Test-ExcludedName {
    param([string]$Name)
    foreach ($prefix in $ExcludeNamePrefix) {
        if (-not [string]::IsNullOrWhiteSpace($prefix) -and
            $Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-TraceChunkWithRetry {
    param(
        [string]$RecipientAddress,
        [datetime]$StartDate,
        [datetime]$EndDate
    )

    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        try {
            return @(Get-MessageTraceV2 `
                -StartDate $StartDate `
                -EndDate $EndDate `
                -RecipientAddress $RecipientAddress `
                -ResultSize 5000 `
                -ErrorAction Stop)
        }
        catch {
            $message = $_.Exception.Message
            $looksThrottled = $message -match 'surpassed the permitted limit|throttl|too many requests|429'
            if (-not $looksThrottled -or $attempt -eq $MaxRetries) {
                throw
            }

            $seconds = [math]::Min(60, [math]::Pow(2, $attempt + 1) * 2)
            Write-Warning "Trace throttled for $RecipientAddress. Retry $($attempt + 1)/$MaxRetries in $seconds seconds."
            Start-Sleep -Seconds $seconds
        }
    }
}

$end = Get-Date
$start = $end.AddDays(-$LookbackDays)
$results = [System.Collections.Generic.List[object]]::new()

$groups = Get-DistributionGroup -ResultSize Unlimited | Where-Object {
    -not (Test-ExcludedName -Name $_.DisplayName)
}

foreach ($group in $groups) {
    Write-Host "Processing: $($group.DisplayName)" -ForegroundColor Cyan
    $address = $group.PrimarySmtpAddress.ToString()
    $lastSeen = $null
    $traceCount = 0
    $status = 'Checked'
    $errorText = $null

    try {
        # Query the lookback window in smaller chunks. This lowers per-query volume and
        # makes retries less expensive when Exchange Online enforces trace limits.
        $cursor = $start
        while ($cursor -lt $end) {
            $chunkEnd = $cursor.AddDays($ChunkDays)
            if ($chunkEnd -gt $end) { $chunkEnd = $end }

            $trace = Get-TraceChunkWithRetry `
                -RecipientAddress $address `
                -StartDate $cursor `
                -EndDate $chunkEnd

            $traceCount += $trace.Count
            if ($trace) {
                $candidate = $trace | Sort-Object Received -Descending | Select-Object -First 1 -ExpandProperty Received
                if (-not $lastSeen -or $candidate -gt $lastSeen) {
                    $lastSeen = $candidate
                }
            }

            $cursor = $chunkEnd
            if ($DelayMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $DelayMilliseconds
            }
        }
    }
    catch {
        $status = 'Error'
        $errorText = $_.Exception.Message
    }

    $results.Add([pscustomobject]@{
        DisplayName        = $group.DisplayName
        PrimarySmtpAddress = $address
        LastMessageSeen    = $lastSeen
        MessagesObserved   = $traceCount
        LookbackDays       = $LookbackDays
        ReviewDecision     = ''
        Status             = $status
        Error              = $errorText
    })
}

$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Audit complete: $OutputPath" -ForegroundColor Green
