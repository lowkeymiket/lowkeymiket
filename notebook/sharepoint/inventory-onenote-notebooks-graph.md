# Inventory Every OneNote Notebook in a Tenant with Microsoft Graph

## Task
A migration was going to change every SharePoint and OneDrive URL in the organization, so every OneNote notebook had to be accounted for first: where it lived, who created it, and whether anyone still used it. No admin center lists notebooks. In a document library a notebook is just a folder of `.one` section files with a `.onetoc2` table of contents.

## Approach
The per-user OneNote API route had already shown its limits ([Tenant-Wide OneNote Inventory](onenote-tenant-inventory.md)). A delegated admin session was no better: `sites/getAllSites` needs an application permission and returned 403, so that crawl saw fewer than half of the sites. The working approach reads the files instead, through app-only Graph with a certificate.

## Solution
The crawler works in five steps:

1. `sites/getAllSites` lists every site, including personal OneDrives. Team sites are walked first.
2. Per drive, `root/search(q='onetoc2')` finds the table-of-contents files in a request or two instead of walking every folder.
3. A hit is not a notebook: section groups and the notebook's recycle bin carry their own `.onetoc2`. The script climbs to the parent folder whose `package` type is `oneNote` and records that folder once.
4. One children listing per notebook counts sections. Last activity is the newest `lastModifiedDateTime` of the folder and its sections.
5. A site is marked done in a JSONL state file only after its rows are written. Each pass stops starting new sites after eight minutes; a final `-RetryErrors` pass re-walks the sites that failed.

Every request goes through one function with `-Method GET` hard-coded and is logged to `requests.log`. The script is safe to run twice: walked sites are skipped, and an interrupted pass redoes at most one site.

## Gotchas
- **`Connect-Graph` is an alias.** The Graph authentication module exports it for `Connect-MgGraph`, and an alias beats a function of the same name. A helper called `Connect-Graph` silently never ran, so its settings were never applied.
- **Hidden SDK retries.** The SDK's default `MaxRetry` of 3 retries each 429 itself (3, 6 and 12 seconds), then throws "Too many retries performed" with status 0: a 21-second stall the script cannot see. `Set-MgRequestContext -MaxRetry 0` surfaces the 429 in under a second, so the script's own back-off runs.
- **A disabled account locks its OneDrive.** When a user's account is disabled at offboarding, SharePoint puts their OneDrive into a locked state and every app-only call to it returns HTTP 423. The notebooks are still there; the crawler cannot read them until the site is unlocked, so they are reported as a known gap rather than silently dropped.
- **Search follows the index.** A brand-new notebook can be missed. A 404 while climbing is a stale index entry, not an error.

## Result
The crawl covered about a thousand sites and found about a thousand notebooks in a handful of eight-minute passes and a few thousand requests, all of them GETs. Nearly nine in ten notebooks lived in personal OneDrives, not team sites, and roughly a third had been active in the last year, which turned "every notebook" into a list short enough to review with owners. Several dozen locked OneDrives, all belonging to disabled accounts, were reported as a known gap instead of vanishing from the totals.

## Script

If you have a similar task, here is a script you can try. It needs the application permission `Sites.Read.All` with a certificate.

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only, resumable inventory of every OneNote notebook folder in a tenant.
.DESCRIPTION
    App-only Microsoft Graph with a certificate (Sites.Read.All). Issues HTTP GET only and logs every request.
    Stops starting new sites after -MaxMinutes; run it again to continue. Walked sites are skipped.
.EXAMPLE
    .\Get-TenantNotebookInventory.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -CertificateThumbprint '<thumbprint>' -OutputPath .\onenote-inventory
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$CertificateThumbprint,
    [string]$OutputPath = '.\onenote-inventory',
    [int]$MaxMinutes = 8,
    [switch]$RetryErrors
)

$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddMinutes($MaxMinutes)
$graph = 'https://graph.microsoft.com/v1.0'
$OutputPath = (New-Item -ItemType Directory -Path $OutputPath -Force).FullName
$stateFile, $sitesFile, $notebookFile, $requestLog = 'state.jsonl', 'sites.json', 'notebooks.jsonl', 'requests.log' |
    ForEach-Object { Join-Path $OutputPath $_ }

function Add-JsonLine([string]$Path, $Object) {
    Add-Content -LiteralPath $Path -Value ($Object | ConvertTo-Json -Compress -Depth 6) -Encoding utf8
}
function Read-JsonLines([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Get-Content -LiteralPath $Path -Encoding utf8 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
    }
}

# The only network call in the script: GET only, logged, and the only place that retries.
function Invoke-GraphGet([string]$Uri) {
    for ($attempt = 1; ; $attempt++) {
        Start-Sleep -Milliseconds 150
        $status = 0; $retryAfter = 0
        try { $body = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject; $status = 200 }
        catch {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
            if ($status -eq 0 -and $_.Exception.Message -match 'HTTP/[\d.]+ (\d{3})') { $status = [int]$Matches[1] }
            try { $retryAfter = [int]$_.Exception.Response.Headers.RetryAfter.Delta.TotalSeconds } catch { }
        }
        Add-Content -LiteralPath $requestLog -Value ("{0}`tGET`t{1}`t{2}" -f (Get-Date).ToString('o'), $Uri, $status)
        if ($status -eq 200) { return [pscustomobject]@{ Ok = $true; Status = 200; Body = $body } }
        if (($status -in 0, 429, 503, 504) -and $attempt -lt 5) {
            $wait = if ($retryAfter -gt 0) { [math]::Min($retryAfter, 180) } else { 10 * $attempt }
            Write-Host "  RETRY: HTTP $status, waiting $wait s"
            Start-Sleep -Seconds $wait
            continue
        }
        return [pscustomobject]@{ Ok = $false; Status = $status }
    }
}

function Get-GraphPages([string]$Uri) {
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $r = Invoke-GraphGet $Uri
        if (-not $r.Ok) { return [pscustomobject]@{ Ok = $false; Status = $r.Status; Items = $items } }
        foreach ($v in @($r.Body.value)) { if ($null -ne $v) { $items.Add($v) } }
        $Uri = $r.Body.'@odata.nextLink'
    }
    [pscustomobject]@{ Ok = $true; Status = 200; Items = $items }
}

# Section groups and the recycle bin carry their own .onetoc2: climb to the folder whose package type is oneNote.
function Resolve-NotebookFolder([string]$DriveId, [string]$FolderId, [hashtable]$Cache) {
    $visited = [System.Collections.Generic.List[string]]::new()
    $notebook = $null
    for ($depth = 0; $FolderId -and $depth -lt 12; $depth++) {
        if ($Cache.ContainsKey($FolderId)) { $notebook = $Cache[$FolderId]; break }
        $visited.Add($FolderId)
        $r = Invoke-GraphGet ('{0}/drives/{1}/items/{2}?$select=id,name,package,parentReference,lastModifiedDateTime,createdBy' -f $graph, $DriveId, $FolderId)
        if (-not $r.Ok) { return [pscustomobject]@{ Notebook = $null; Failed = $r } }
        if ($r.Body.package.type -eq 'oneNote') { $notebook = $r.Body; break }
        $FolderId = $r.Body.parentReference.id
    }
    foreach ($id in $visited) { $Cache[$id] = $notebook }
    [pscustomobject]@{ Notebook = $notebook; Failed = $null }
}

try {
    Import-Module Microsoft.Graph.Authentication
    Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ContextScope Process -NoWelcome
    Set-MgRequestContext -MaxRetry 0 | Out-Null   # let Invoke-GraphGet see every 429
    Write-Host 'SUCCESS: Connected to Microsoft Graph (app-only)'
}
catch { Write-Host "ERROR: Could not connect to Microsoft Graph: $($_.Exception.Message)"; exit 1 }

$exitCode = 0
try {
    if (-not (Test-Path -LiteralPath $sitesFile)) {
        $list = Get-GraphPages ('{0}/sites/getAllSites?$select=id,webUrl,isPersonalSite&$top=999' -f $graph)
        if (-not $list.Ok) { throw "getAllSites failed with HTTP $($list.Status) (needs the Sites.Read.All application permission)" }
        $list.Items | Select-Object id, webUrl, isPersonalSite | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$sitesFile.tmp" -Encoding utf8
        Move-Item -LiteralPath "$sitesFile.tmp" -Destination $sitesFile -Force
        Write-Host "SUCCESS: getAllSites returned $($list.Items.Count) sites"
    }
    $sites = @(Get-Content -LiteralPath $sitesFile -Raw | ConvertFrom-Json | Sort-Object { [bool]$_.isPersonalSite })   # team sites first
    $walked = @{}
    foreach ($rec in Read-JsonLines $stateFile) { $walked[$rec.id] = $rec }
    $todo = @($sites | Where-Object { -not $walked.ContainsKey($_.id) -or ($RetryErrors -and $walked[$_.id].status -ne 'ok') })
    Write-Host "Sites: $($sites.Count) known, $($todo.Count) to walk in this pass"

    foreach ($site in $todo) {
        if ((Get-Date) -gt $deadline) { Write-Host "Stopped after $MaxMinutes minutes. Run the script again to continue."; break }
        $siteStatus = 'ok'; $siteHttp = $null
        $rows = [System.Collections.Generic.List[object]]::new()

        $drives = Get-GraphPages ('{0}/sites/{1}/drives?$select=id,name,webUrl' -f $graph, $site.id)
        if (-not $drives.Ok) { $siteStatus = 'error'; $siteHttp = $drives.Status }   # 423 = OneDrive locked (disabled account)

        foreach ($drive in $drives.Items) {
            $search = Get-GraphPages ('{0}/drives/{1}/root/search(q=''onetoc2'')?$select=id,name,parentReference' -f $graph, $drive.id)
            if (-not $search.Ok) { $siteStatus = 'error'; $siteHttp = $search.Status; continue }
            $cache = @{}; $seen = @{}
            foreach ($hit in @($search.Items | Where-Object { $_.name -like '*.onetoc2' })) {
                $resolved = Resolve-NotebookFolder $drive.id $hit.parentReference.id $cache
                if ($resolved.Failed) {
                    if ($resolved.Failed.Status -ne 404) { $siteStatus = 'error'; $siteHttp = $resolved.Failed.Status }   # 404 = stale index entry
                    continue
                }
                $nb = $resolved.Notebook
                if (-not $nb -or $seen.ContainsKey($nb.id)) { continue }
                $seen[$nb.id] = $true

                $children = Get-GraphPages ('{0}/drives/{1}/items/{2}/children?$select=name,file,folder,lastModifiedDateTime&$top=200' -f $graph, $drive.id, $nb.id)
                if (-not $children.Ok) { $siteStatus = 'error'; $siteHttp = $children.Status }
                $sections = @($children.Items | Where-Object { $_.file -and $_.name -like '*.one' -and $_.name -notlike 'OneNote_*' })
                $groups = @($children.Items | Where-Object { $_.folder -and $_.name -ne 'OneNote_RecycleBin' })
                $lastActivity = @($nb.lastModifiedDateTime) + @($sections.lastModifiedDateTime) + @($groups.lastModifiedDateTime) |
                    Where-Object { $_ } | ForEach-Object { [datetime]$_ } | Sort-Object -Descending | Select-Object -First 1

                $rows.Add([ordered]@{
                    siteUrl       = $site.webUrl
                    personalSite  = [bool]$site.isPersonalSite
                    notebook      = $nb.name
                    location      = ('{0}{1}/{2}' -f [uri]::UnescapeDataString($drive.webUrl), ($nb.parentReference.path -replace '^/drives/[^/]+/root:'), $nb.name)
                    createdBy     = $nb.createdBy.user.displayName
                    sections      = $sections.Count
                    sectionGroups = $groups.Count
                    lastActivity  = $(if ($lastActivity) { $lastActivity.ToString('yyyy-MM-dd') })
                    key           = ('{0}|{1}' -f $drive.id, $nb.id)
                })
            }
        }

        # Rows first, state marker last: an interrupted pass redoes this site and nothing else.
        foreach ($row in $rows) { Add-JsonLine $notebookFile $row }
        Add-JsonLine $stateFile ([ordered]@{ id = $site.id; status = $siteStatus; http = $siteHttp })
        $walked[$site.id] = [pscustomobject]@{ id = $site.id; status = $siteStatus; http = $siteHttp }
        if ($siteStatus -ne 'ok') { Write-Host "ERROR: $($site.webUrl) returned HTTP $siteHttp" }
        elseif ($rows.Count) { Write-Host "SUCCESS: $($site.webUrl): $($rows.Count) notebook(s)" }
    }

    $notebooks = @(Read-JsonLines $notebookFile | Group-Object key | ForEach-Object { $_.Group[-1] })
    $notebooks | Export-Csv -LiteralPath (Join-Path $OutputPath 'notebooks.csv') -NoTypeInformation -Encoding utf8
    $active = @($notebooks | Where-Object { $_.lastActivity -and [datetime]$_.lastActivity -ge (Get-Date).AddMonths(-12) }).Count
    $locked = @($walked.Values | Where-Object { $_.http -eq 423 }).Count
    $left = @($sites | Where-Object { -not $walked.ContainsKey($_.id) }).Count
    Write-Host "Notebooks: $($notebooks.Count), $active active in the last 12 months. Sites locked (disabled account), HTTP 423: $locked."
    if ($left) { Write-Host "PARTIAL: $left site(s) not walked yet. Run the script again to continue." }
    else { Write-Host "SUCCESS: Every site walked. Results: $(Join-Path $OutputPath 'notebooks.csv')" }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
exit $exitCode
```
