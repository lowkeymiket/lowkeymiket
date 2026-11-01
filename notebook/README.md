# IT Engineering Notebook

Scripts, configurations, and troubleshooting notes from problems I have run into while administering Microsoft 365, Entra ID, SharePoint, Windows endpoints, mail flow, and network infrastructure.

Nothing here is intended to be a universal runbook. These are sanitized versions of fixes that were useful in a specific environment. Review the assumptions and test them before using anything in production.

## Folders

### Networking & firewalls
- [Cleanup of a retired Azure IPsec tunnel and its dependencies](networking/fortigate-legacy-azure-ipsec-cleanup.md)

### Microsoft 365 & identity
- [Microsoft 365 tenant consolidation and endpoint cutover](microsoft-365/m365-tenant-consolidation.md)
- [Entra join and MDM state validation](microsoft-365/validate-entra-mdm-state.md)
- [Read-only Entra ID tenant audit through delegated Graph](microsoft-365/audit-entra-tenant-read-only-graph.md)
- [Bulk employee ID updates in Entra ID](microsoft-365/update-entra-employee-id.md)
- [Safe B2B guest removal](microsoft-365/remove-b2b-guests-safely.md)
- [License migration between SKUs with add-before-remove validation](microsoft-365/migrate-license-atomic.md)
- [Entra group membership export through Graph](microsoft-365/export-entra-group-members.md) (read-only helper)

### Exchange & communications
- [Exchange Online / Exclaimer transport-path analysis](exchange/analyze-mail-transport-headers.md)
- [Targeted calendar cleanup with an approval gate](exchange/calendar-item-targeted-cleanup.md)
- [Archive mailbox enablement from CSV](exchange/enable-mailbox-archive-from-csv.md)
- [Mailbox-auditing state review](exchange/audit-mailbox-auditing-state.md) (read-only helper)
- [Full mailbox property export for troubleshooting](exchange/export-mailbox-full-properties.md) (read-only helper)
- [Distribution-list usage auditing with throttling handling](exchange/audit-distribution-list-last-used.md)
- [Exchange group membership export](exchange/export-exchange-group-memberships.md) (read-only helper)
- [Phone-number reconciliation between source records and Teams assignments](exchange/audit-phone-number-reconciliation.md)

### SharePoint & data
- [Restore large numbers of recycle-bin items](sharepoint/restore-recycle-bin-items.md)
- [Remediate ownerless sites](sharepoint/remediate-ownerless-sites.md)
- [Remove stale user identities after rehire/account conflicts](sharepoint/remove-stale-user-profile.md)
- [Tenant-wide OneNote inventory](sharepoint/onenote-tenant-inventory.md)
- [Every OneNote notebook in a tenant, through app-only Graph](sharepoint/inventory-onenote-notebooks-graph.md)

### Endpoint automation
- Level RMM agent migration between tenants on [Windows](endpoint/migrate-level-agent-tenant-windows.md) and [macOS](endpoint/migrate-level-agent-tenant-macos.md)
- [Silent Sophos deployment through RMM, sequenced around a tenant-migration re-ACL stall](endpoint/install-sophos-silent.md)
- [Intune endpoint baseline](endpoint/intune-endpoint-baseline.md)
- [Legacy application cleanup after migration](endpoint/remove-legacy-apps-by-name.md)

### Cloud & self-hosting
- [Self-hosted apps on a Synology NAS behind Cloudflare Tunnel, no inbound ports](cloud/cloudflare-tunnel-synology-docker.md)
- [Faithful PDFs from Word files with a Gotenberg sidecar, internal network only](cloud/gotenberg-pdf-sidecar.md)

## Read-only helpers

Smaller read-only helpers that are useful during troubleshooting but do not need a full problem/fix entry sit in the folder of the service they read, marked "read-only helper" above: mailbox property exports, group membership exports, and mailbox-auditing checks.

## Documentation

Entries are kept short and generally follow:

1. **Problem**
2. **Investigation**, when diagnosis matters
3. **Fix**
4. **Safety / Notes**, when there are meaningful safeguards or caveats
5. **Result**

Some fixes are configuration-only. I have not added fake scripts just to make those entries look more substantial.

## Sanitization

Domains, employee identities, tenant/application IDs, internal paths, IP addresses, and customer data are removed or parameterized where needed. The scripts are sanitized, generalized versions of the production fixes.

Scripts that make changes are additionally published in read-only mode: a forced dry-run or an execution guard prevents them from modifying anything as published. Each affected entry carries a publication note.
