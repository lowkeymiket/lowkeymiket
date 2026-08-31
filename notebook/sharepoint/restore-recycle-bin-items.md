# Bulk Restore SharePoint Recycle Bin Items

## Problem
A large number of files in an important SharePoint document hierarchy had been deleted by the System Account. Manual restoration was impractical because the reviewed recovery set contained thousands of items.

## Investigation
We first enumerated recycle-bin metadata and filtered the candidates by directory, deleting identity, and other review criteria. An initial attempt to use `Restore-PnPRecycleBinItem` in batches exposed parameter-set limitations, so the recovery path was changed to the SharePoint REST recycle-bin endpoint.

## Fix
The final workflow imports a reviewed CSV containing recycle-bin GUIDs and calls `/_api/site/RecycleBin/GetById('<id>')/Restore()` for each item through `Invoke-PnPSPRestMethod`.

## Safety / Notes
- Restoration is driven by a reviewed CSV rather than the entire recycle bin.
- A preview of selected records is displayed before execution.
- Each restore is wrapped in exception handling.
- Progress is displayed per item.
- Existing-file conflicts and invalid restore candidates are surfaced rather than suppressed.

## Result
The process converted a potentially enormous manual recovery task into a controlled bulk-restoration workflow and exposed collisions where a file already existed at the original path.

## Notes
**Recovered from production console sessions and parameterized for publication.**
