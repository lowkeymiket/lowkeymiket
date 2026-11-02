# Bulk Restore SharePoint Recycle Bin Items

## Problem
A large number of files in an important SharePoint document hierarchy had been deleted by the System Account. Manual restoration was impractical because the reviewed recovery set contained thousands of items.

## Approach
We first enumerated recycle-bin metadata and filtered the candidates by directory, deleting identity, and other review criteria. An initial attempt to use `Restore-PnPRecycleBinItem` in batches exposed parameter-set limitations, so the recovery path was changed to the SharePoint REST recycle-bin endpoint.

## Fix
The final workflow imports a reviewed CSV containing recycle-bin GUIDs and calls `/_api/site/RecycleBin/GetById('<id>')/Restore()` for each item through `Invoke-PnPSPRestMethod`. Each restore is wrapped in exception handling, and progress is displayed per item. Existing-file conflicts and invalid restore candidates are surfaced.

## Result
The process converted a potentially enormous manual recovery task into a controlled bulk-restoration workflow and exposed collisions where a file already existed at the original path.

## Script

If you have a similar problem, here is a script you can try. As published, a read-only guard stops the script before it makes any change.

```powershell
param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [int]$DelayMilliseconds = 500
)

# Read-only for publication: this guard stops the script before any
# change is made. The rest is preserved to document the approach.
$ReadOnly = $true
if ($ReadOnly) {
    Write-Output 'READ-ONLY published copy; execution disabled.'
    exit 0
}

# Requires an existing Connect-PnPOnline session to the target site.

$items = Import-Csv $CsvPath
Write-Host "Loaded $($items.Count) items from CSV."

for ($i = 0; $i -lt $items.Count; $i++) {
    $item = $items[$i]
    try {
        Write-Host "[$($i + 1) / $($items.Count)] Restoring: $($item.DirName)/$($item.Title)"
        $endpoint = "/_api/site/RecycleBin/GetById('$($item.Id)')/Restore()"
        Invoke-PnPSPRestMethod -Method Post -Url $endpoint | Out-Null
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
    catch {
        Write-Host "FAILED: $($item.DirName)/$($item.Title)" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
```
