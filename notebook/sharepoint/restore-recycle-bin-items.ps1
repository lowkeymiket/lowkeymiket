param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [int]$DelayMilliseconds = 500
)

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
