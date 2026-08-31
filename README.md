# Hi, I'm Mike 👋

IT Infrastructure & Microsoft 365 Lead with 15+ years of experience securing, modernizing, and consolidating technology environments across multiple companies.

## What I do

- **Microsoft 365 administration**: Exchange Online, Teams, SharePoint, and OneDrive across multi-company environments, including bulk mailbox operations driven by the Microsoft Graph API
- **Identity & security**: Entra ID, Conditional Access, passwordless authentication (FIDO2, Windows Hello for Business), RBAC, and risk-based controls
- **Tenant consolidation**: technical project lead for consolidating four independent Microsoft 365 tenants into one (roughly 1,000 mailboxes, 650 OneDrive accounts, 300 SharePoint sites, and 200 managed devices)
- **PowerShell automation**: 31 production scripts for administration, migration, reporting, and endpoint management, built to run silently and idempotently at fleet scale through RMM tooling
- **Azure & endpoints**: VMs, networking, storage, backup, and monitoring, plus Intune device management from enrollment through compliance
- **Internal tooling**: small end-user utilities in C#/WinForms (self-service cache cleanup, technician-facing removal tools)

## How I work

- I automate the boring stuff so I can be paranoid about the dangerous stuff.
- Scripts should be boring: single purpose, obvious SUCCESS/ERROR output, exit codes an RMM platform can parse, and safe to run twice.
- Big changes ship in waves. A four-tenant migration and a two-line registry fix get the same treatment: pilot, validate, expand.
- I'd rather ship a small fix that works on hundreds of machines than a clever one that works on mine.
- Technology serves the business: every recommendation weighs security, cost, user experience, and whether someone can still support it in three years.
- Every script ships with comment-based help. Not because I love writing documentation, but because the next admin is usually future me, and future me always has questions.

## Engineering notebook 📓

I keep a sanitized [**IT Engineering Notebook**](notebook/README.md) of problems I have run into in production and what fixed them: scripts, configurations, and troubleshooting notes. A few entries:

- [Microsoft 365 tenant consolidation and endpoint cutover](notebook/publishable/migrations/m365-tenant-consolidation.md)
- [Targeted calendar cleanup with an approval gate](notebook/publishable/microsoft-365/calendar-item-targeted-cleanup.md)
- [Bulk SharePoint recycle-bin restore](notebook/publishable/sharepoint/restore-recycle-bin-items.md)
- [Migrating the Level RMM agent between tenants](notebook/publishable/windows/migrate-level-agent-tenant.md)
- [Distribution-list audit that had to survive Exchange throttling](notebook/publishable/microsoft-365/audit-distribution-list-last-used.md)

## Toolbox

`PowerShell 7` · `Microsoft Graph API` · `Microsoft 365` · `Entra ID` · `Intune` · `Azure` · `Conditional Access` · `Windows 11` · `RMM platforms` · `C# / WinForms` · `Git & GitHub`

---

Most of my day-to-day work lives in private repositories. The [notebook](notebook/README.md) covers the interesting parts in sanitized form, and I'm happy to walk through real examples in an interview.

<!--
Rule: no personal info on this page or anywhere on GitHub (no phone, emails,
location, resume content, employer or tenant names). Contact details live on
the resume only.
Optional future addition: certifications (professional credentials only).
-->
