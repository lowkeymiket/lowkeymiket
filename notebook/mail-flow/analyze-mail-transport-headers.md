# Exchange Online / Exclaimer Transport Path Analysis

## Problem

A user could receive mail but outbound external messages failed with `554 5.4.14 Hop count exceeded`, and other outbound and forwarded mail intermittently behaved incorrectly. The environment routed messages through Microsoft 365 and Exclaimer Cloud for signature processing, so the visible NDR alone could not identify where the path went wrong. Troubleshooting required proving the actual SMTP path rather than assuming Exchange Online was the only transport hop.

## Investigation

Full RFC message headers were the evidence source: `Received`, `Authentication-Results`, and Exclaimer-specific processing headers. The recovered production headers show Exchange Online handing an outbound message to Exclaimer, Exclaimer processing it, and the message returning to Microsoft 365 protection. SPF and DMARC passed in the captured example, which separated authentication health from transport-routing health: the problem class was connector and routing behavior, not authentication.

## Fix

The troubleshooting method reconstructed the transport chain hop by hop, correlated sender IPs and HELO values, and identified Exclaimer processing markers to establish where a routing loop or connector mismatch could occur.

The accompanying script packages that method. It parses an `.eml` file and:

- unfolds RFC header continuations;
- extracts each `Received` hop in sequence;
- identifies `from` and `by` hosts;
- extracts authentication results;
- surfaces Exclaimer processing headers;
- flags transport hosts that recur multiple times; and
- optionally exports the reconstructed hop path to CSV.

Repeated hosts are not automatically declared a loop because legitimate mail paths can revisit infrastructure. The output makes the route visible so it can be compared with connector and transport-rule configuration.

## Safety / Notes

- The script is read-only and operates on a local message file. It does not connect to Exchange Online or alter connectors, rules, or mailboxes.
- Routing conclusions were based on hop order rather than a single NDR string.
- Authentication results were evaluated separately from connector behavior.
- Public samples should remove real email addresses, tenant IDs, internal hostnames, and message IDs.

## Result

The original incident was narrowed from a generic external-send failure to a mail-flow problem on the Microsoft 365 / Exclaimer route, giving a concrete path for reviewing connector scoping and preventing a repeated relay path. The recovered headers independently prove the environment's actual route through Exclaimer and back into Exchange Online protection.

## Notes
**Public reconstruction backed by recovered production headers.** The analyzer packages the method used during the incident; the header evidence itself stays private.

## Publication note

The script below is read-only by design: it only queries and reports, and makes no changes.

## Script

```powershell
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
```
