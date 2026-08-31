# IT Engineering Notebook

Scripts, configurations, and troubleshooting notes from problems I have run into while administering Microsoft 365, Entra ID, SharePoint, Windows endpoints, mail flow, and network infrastructure.

Nothing here is intended to be a universal runbook. These are sanitized versions of fixes that were useful in a specific environment. Review the assumptions and test them before using anything in production.

## Fixes

### Microsoft 365
- Bulk employee ID updates in Entra ID
- License migration between SKUs with add-before-remove validation
- Targeted calendar cleanup with an approval gate
- Distribution-list usage auditing with throttling handling
- Tenant-wide OneNote inventory
- Safe B2B guest removal
- Archive mailbox enablement from CSV

### SharePoint
- Restore large numbers of recycle-bin items
- Remove stale user identities after rehire/account conflicts
- Remediate ownerless sites

### Security and mail flow
- Silent Sophos deployment through RMM, sequenced around a tenant-migration re-ACL stall
- Exchange Online / Exclaimer transport-path analysis

### Networking
- Cleanup of a retired Azure IPsec tunnel and its dependencies

### Migrations and endpoints
- Microsoft 365 tenant consolidation and endpoint cutover
- Entra join and MDM state validation
- Intune endpoint baseline
- Level RMM agent migration between tenants on Windows and macOS
- Legacy application cleanup after migration

### Teams Voice
- Phone-number reconciliation between source records and Teams assignments

## Utilities

`utilities/` contains smaller read-only helpers that are useful during troubleshooting but do not need a full problem/fix entry in the main collection. Examples include mailbox property exports, group membership exports, and mailbox-auditing checks.

## Documentation

Entries are kept short and generally follow:

1. **Problem**
2. **Investigation**, when diagnosis matters
3. **Fix**
4. **Safety / Notes**, when there are meaningful safeguards or caveats
5. **Result**

Some fixes are configuration-only. I have not added fake scripts just to make those entries look more substantial.

## Sanitization

Domains, employee identities, tenant/application IDs, internal paths, IP addresses, and customer data are removed or parameterized where needed. Some scripts are recovered source and others are sanitized reconstructions of the production fix.
