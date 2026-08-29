# Microsoft 365 Multi-Tenant Consolidation

## Executive summary

Served as a core engineer on a major Microsoft 365 consolidation combining three separate environments into a common tenant.

The migration inventory included approximately:

- 1,050 users
- 809 mailboxes
- 500 OneDrive accounts
- 275 SharePoint sites
- 242 Microsoft 365 Groups
- 120 Teams
- 100 distribution lists
- 37 mail contacts
- 84 Power Platform assets
- **76.6 TB of total data** (~56 TB OneDrive, ~16.6 TB Exchange mail and archives)

The original project was scoped at roughly 16 weeks. Additional resources were added through a change order to target a roughly seven-week migration window. The major constraints were not simply manpower: Microsoft and Quest service throughput, discovery, migration preparation, identity mapping, SharePoint/OneDrive URL changes, and link remapping all shaped the timeline.

## The problem

A Microsoft 365 tenant is not one system. It is a collection of interdependent services:

```
Identity
   |
   +-- Exchange Online
   +-- OneDrive
   +-- SharePoint
   +-- Teams
   +-- Microsoft 365 Groups
   +-- Power Platform
   +-- Intune
   +-- Windows device identity
   +-- Licensing
```

- Moving an Exchange mailbox successfully does not mean the user's workstation is correctly enrolled.
- Moving a user's identity does not guarantee their SharePoint and OneDrive references remain usable.
- A Windows endpoint successfully joining the target Entra tenant does not mean it successfully enrolled in Intune.

That last distinction became one of the most important lessons of the project (see the [Intune enrollment case study](02-intune-enrollment-after-migration.md)).

## Migration tooling

Quest On Demand Migration was a major component of the workflow. The project required preparing and validating data before handing it to migration tooling:

- Resolving identities
- Source-to-target mappings
- Destination UPN preparation
- Group preparation
- Migration collections
- Endpoint migration packages
- User communication
- Workload validation

## Identity normalization

Some source datasets used display names or other human-friendly values rather than the exact UPNs migration tooling requires. Rather than repeatedly resolving those values during each operation, identity data was normalized first:

```powershell
$SourceUsers = Import-Csv ".\SourceUsers.csv"

$ResolvedUsers = foreach ($Row in $SourceUsers) {

    $Matches = Get-MgUser `
        -Filter "displayName eq '$($Row.DisplayName)'"

    if ($Matches.Count -eq 1) {

        $User = $Matches[0]

        [PSCustomObject]@{
            DisplayName = $User.DisplayName
            SourceUPN   = $User.UserPrincipalName
            TargetUPN   = (
                $User.UserPrincipalName.Split("@")[0] +
                "@destination.example"
            )
            Status      = "Resolved"
        }
    }
    else {
        [PSCustomObject]@{
            DisplayName = $Row.DisplayName
            SourceUPN   = $null
            TargetUPN   = $null
            Status      = "Needs Review"
        }
    }
}

$ResolvedUsers |
    Export-Csv ".\ResolvedUsers.csv" -NoTypeInformation
```

The important part was not the string manipulation. The important part was the match policy:

```
One match    -> proceed
Zero matches -> investigate
Many matches -> investigate
```

Ambiguous identities were never automatically pushed downstream. The consolidated output became a known-good input for every later operation.

## Device migration complications

One migration failure involved Quest attempting to register a device *after* a provisioning package had renamed it. The device was healthy from Windows' perspective:

```
AzureAdJoined : YES
DomainJoined  : NO
Domain        : WORKGROUP
```

…but Quest reported errors like:

```
No objects found for Device: '<device-name>'

An ActiveDirectory Endpoint with Domain 'WORKGROUP'
could not be found
```

The evidence suggested the rename occurred before Quest completed its registration, creating a mismatch between the current Windows hostname, the Entra object, Quest's migration inventory, and the device name Quest expected.

This is a good example of why migration failures can live in the *migration orchestration layer* even when Windows and Entra each appear healthy on their own.

## SharePoint and OneDrive complexity

Moving data is only part of a migration:

```
Old SharePoint URL
        |
        v
Target SharePoint URL
```

Any documents, links, bookmarks, workflows, or references pointing to the original URL may need correction — significant when hundreds of SharePoint sites and OneDrives are involved.

## Validation

Migration validation had to be performed **by workload**. A single "migration completed" status is not enough:

```
User Exists              [ ]
Mailbox Migrated         [ ]
Archive Migrated         [ ]
OneDrive Migrated        [ ]
SharePoint Access        [ ]
Teams Access             [ ]
Device Joined            [ ]
Intune Enrolled          [ ]
Office Activated         [ ]
Outlook Working          [ ]
OneDrive Syncing         [ ]
Correct License          [ ]
```

## Lessons learned

**Migration tooling has its own state.** Microsoft Entra, Windows, Intune, and Quest can each disagree about what has happened.

**Exact identity mapping matters.** Display names are user-friendly identifiers, not safe automation keys.

**Device identity and device management are separate.** This led directly to the [Intune enrollment case study](02-intune-enrollment-after-migration.md).

**Migration speed has external constraints.** Adding engineers does not remove service throttling, network throughput, Microsoft limits, vendor limits, data volume, or link remapping requirements.

## Technologies

Microsoft 365 · Microsoft Entra ID · Exchange Online · SharePoint Online · OneDrive · Microsoft Teams · Intune · Quest On Demand Migration · PowerShell · Microsoft Graph · CSV processing
