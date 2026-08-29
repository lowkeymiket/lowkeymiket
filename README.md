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

## Case studies

I keep a sanitized [**IT Engineering Showcase**](showcase/README.md) of deep-dive case studies from production work — the problems where judgment mattered, not just tooling. Highlights:

- [Microsoft 365 multi-tenant consolidation](showcase/01-m365-tenant-consolidation.md) — three environments into one tenant: ~1,050 users, 809 mailboxes, 76.6 TB of data
- [Intune enrollment failure after tenant migration](showcase/02-intune-enrollment-after-migration.md) — devices that joined the new tenant but silently escaped management
- [Safe tenant-wide Exchange calendar cleanup](showcase/03-exchange-calendar-cleanup.md) — destructive automation with a human approval gate
- [SharePoint stale identity cleanup](showcase/04-sharepoint-stale-identity-cleanup.md) — why finding 14,000 stale entries is not permission to delete them

## Toolbox

`PowerShell 7` · `Microsoft Graph API` · `Microsoft 365` · `Entra ID` · `Intune` · `Azure` · `Conditional Access` · `Windows 11` · `RMM platforms` · `C# / WinForms` · `Git & GitHub`

---

Most of my day-to-day work lives in private repositories — the [showcase](showcase/README.md) covers the interesting parts in sanitized form, and I'm happy to walk through real examples in an interview.

<!--
Rule: no personal info on this page or anywhere on GitHub (no phone, emails,
location, resume content, employer or tenant names). Contact details live on
the resume only.
Optional future addition: certifications (professional credentials only).
-->
