# IT Engineering Showcase

Deep-dive case studies from production work across Microsoft 365 engineering, identity, cloud migration, endpoint management, automation, and security.

This is not a catalog of every ticket solved. Each case here made the cut for one reason: it's a problem where **judgment mattered**: an unusual failure mode, a destructive operation that had to be engineered safely, or a design decision with real security consequences. Routine troubleshooting doesn't appear on this page.

> **Sanitization note:** All case studies are sanitized. Employee names, company domains, tenant IDs, internal URLs, GUIDs (other than public Microsoft service-plan IDs), certificates, and secrets have been replaced with placeholders such as `example.com`. The problems, methods, and outcomes are real.

---

## Case studies

| Case study | What it demonstrates |
|---|---|
| [Microsoft 365 Multi-Tenant Consolidation](01-m365-tenant-consolidation.md) | Consolidating three environments into one tenant (~1,050 users, 809 mailboxes, 76.6 TB of data) across identity, Exchange, SharePoint, OneDrive, Teams, and endpoints |
| [Intune Enrollment Failure After Tenant Migration](02-intune-enrollment-after-migration.md) | Layer-by-layer diagnosis of devices that joined the new Entra tenant but silently failed MDM enrollment, ultimately traced to target-tenant Conditional Access policies blocking device registration |
| [Safe Tenant-Wide Exchange Calendar Cleanup](03-exchange-calendar-cleanup.md) | Removing a stale forwarded invite tenant-wide before employees joined a rescheduled company-wide call at the wrong time, without skipping the approval gate: discover → export → human approval → controlled execution |
| [SharePoint Stale "(Inactive)" Identity Cleanup](04-sharepoint-stale-identity-cleanup.md) | Site-level identity internals, PnP PowerShell, and the judgment to *not* bulk-delete 14,000+ stale entries |
| [Conditional Access Architecture & MFA Redesign](05-conditional-access-architecture.md) | A three-tier access model driven by identity attributes: a dynamic-group security boundary, attribute-based offboarding, trusted locations, service-account exceptions, legacy auth lockdown |
| [Windows Hello Failure After Tenant Migration](06-windows-hello-after-migration.md) | Working down the stack (tenant state, NGC, PIN, biometrics) until an unrelated settings toggle re-initialized the biometric stack, exposing stale per-identity state as the real fault |

---

## The common thread

The theme of this portfolio is not "I know a lot of Microsoft products." It is:

> I can take ownership of a production problem even when it crosses identity, endpoints, Microsoft 365, SaaS applications, Windows, networking, and automation. I determine which layer is actually failing, build a controlled fix, validate it at small scale, and only then expand the change.

The same loop shows up in every case study:

```
Reproduce
   |
Gather Evidence
   |
Identify System Boundary
   |
Eliminate Hypotheses
   |
Test Safely
   |
Validate
   |
Automate
   |
Scale
```
