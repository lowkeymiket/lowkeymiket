[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File not found: $Path"
}

$raw = Get-Content -LiteralPath $Path -Raw

# Read only the RFC 5322 header block. Header folding is preserved, then unfolded.
$headerBlock = ($raw -split "\r?\n\r?\n", 2)[0]
$unfolded = $headerBlock -replace "\r?\n[\t ]+", ' '

$received = [regex]::Matches($unfolded, '(?im)^Received:\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
$authResults = [regex]::Matches($unfolded, '(?im)^Authentication-Results:\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
$exclaimer = [regex]::Matches($unfolded, '(?im)^(X-Exclaimer[^:]*):\s*(.+)$') | ForEach-Object {
    [pscustomobject]@{ Header = $_.Groups[1].Value; Value = $_.Groups[2].Value.Trim() }
}

$hops = for ($i = 0; $i -lt $received.Count; $i++) {
    $line = $received[$i]
    $from = if ($line -match '(?i)\bfrom\s+([^\s\(]+)') { $Matches[1] } else { $null }
    $by   = if ($line -match '(?i)\bby\s+([^\s\(]+)')   { $Matches[1] } else { $null }

    [pscustomobject]@{
        Hop      = $i + 1
        FromHost = $from
        ByHost   = $by
        Raw      = $line
    }
}

$hostCounts = @{}
foreach ($hop in $hops) {
    foreach ($hopHost in @($hop.FromHost, $hop.ByHost)) {
        if ($hopHost) {
            $key = $hopHost.ToLowerInvariant()
            if ($hostCounts.ContainsKey($key)) { $hostCounts[$key]++ } else { $hostCounts[$key] = 1 }
        }
    }
}

$repeatedHosts = $hostCounts.GetEnumerator() |
    Where-Object Value -gt 1 |
    Sort-Object Value -Descending |
    ForEach-Object { [pscustomobject]@{ Host = $_.Key; Count = $_.Value } }

Write-Host "Received headers: $($hops.Count) (displayed in message order, newest first)"
Write-Host "Authentication-Results headers: $($authResults.Count)"
Write-Host "Exclaimer headers: $($exclaimer.Count)"

if ($repeatedHosts) {
    Write-Warning 'Repeated transport hosts detected. Review for legitimate relay reuse versus a possible loop.'
    $repeatedHosts | Format-Table -AutoSize
}

if ($exclaimer) {
    Write-Host "`nExclaimer markers:"
    $exclaimer | Format-Table -AutoSize
}

Write-Host "`nTransport path:"
$hops | Select-Object Hop, FromHost, ByHost | Format-Table -AutoSize

if ($CsvPath) {
    $hops | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported hop data to $CsvPath"
}
