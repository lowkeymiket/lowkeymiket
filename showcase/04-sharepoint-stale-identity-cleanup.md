# SharePoint Stale "(Inactive)" Identity Cleanup

## Executive summary

Rehired and previously disabled employees could remain cached inside SharePoint as stale "(Inactive)" identities even though their current Microsoft Entra account was correct.

Fixing it required going *beneath* Entra and the Microsoft 365 admin portals into SharePoint's own site-level user information. The investigation also surfaced **thousands** of inactive-looking entries tenant-wide — creating a second, more important challenge: recognizing that large-scale discovery did **not** justify large-scale deletion.

## Symptom

Users could appear in SharePoint or OneDrive people pickers as:

```
Employee Name (Inactive)
```

even though the active Entra identity was healthy.

## Why Entra changes did not fix it

SharePoint stores user information at the **site level**:

```
Microsoft Entra ID
        |
        v
SharePoint User Information List (per site)
```

Once SharePoint has cached a principal, the SharePoint representation can outlive identity changes elsewhere. A correct Entra identity does not necessarily equal a correct SharePoint identity.

## Investigation

PnP PowerShell was used to enumerate SharePoint's cached users:

```powershell
Get-PnPUser |
    Where-Object { $_.Title -like "*(Inactive)*" } |
    Select-Object Id, Title, LoginName, Email, IsSiteAdmin |
    Format-List
```

The login names followed the SharePoint claims/membership format:

```
i:0#.f|membership|user@example.com
```

## Target selection

Rather than deleting by display name alone, candidates had to match on multiple properties:

```powershell
$Candidate = Get-PnPUser |
    Where-Object {
        $_.Email     -eq "user@example.com" -and
        $_.LoginName -eq "i:0#.f|membership|user@example.com" -and
        $_.Title     -like "*(Inactive)*"
    }
```

…and the script required **exactly one** target before acting:

```powershell
if ($Candidate.Count -ne 1) {
    throw "Expected exactly one stale SharePoint identity."
}

Remove-PnPUser -Identity $Candidate.LoginName -Force
```

## Permission handling

Some sites required temporarily granting site-level administration to perform the cleanup. That access was treated as temporary by design:

```
Grant access
    |
Perform cleanup
    |
Validate
    |
Remove temporary access
```

## The bigger discovery

Tenant-wide enumeration revealed approximately:

```
14,249 inactive-looking entries
```

That number could easily tempt an administrator into "great, let's clean all of them." That would have been reckless.

## Why bulk deletion was rejected

Historical principals may still be associated with:

- Document metadata (created by / modified by)
- List items
- Historical permissions
- Sharing records
- Audit context
- Legacy content ownership

The entries *looked* stale. That did not prove they were *safe to delete*.

## Engineering lesson

```
Large discovery result  !=  Large remediation scope
```

The discovery increased caution. It did not increase confidence.

## Result

Known problematic identities were surgically removed, resolving the user-facing people-picker issues, while a broad tenant-wide purge was deliberately avoided.

## Technologies

SharePoint Online · OneDrive · Microsoft Entra ID · PnP PowerShell · PowerShell
