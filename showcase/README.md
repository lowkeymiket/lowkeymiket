# IT Engineering Showcase

Deep-dive case studies from production work across Microsoft 365 engineering, identity, cloud migration, endpoint management, automation, SaaS integrations, and security.

This is not a catalog of every ticket solved. These are the projects and incidents that best demonstrate technical depth, troubleshooting methodology, production judgment, automation, scale, and security thinking — real problems where moving from symptom to root cause actually mattered.

> **Sanitization note:** All case studies are sanitized. Employee names, company domains, tenant IDs, internal URLs, GUIDs (other than public Microsoft service-plan IDs), certificates, and secrets have been replaced with placeholders such as `example.com`. The problems, methods, and outcomes are real.

---

## Featured Projects

Large-scale engineering work: migration, identity, automation, and security architecture.

| Case study | What it demonstrates |
|---|---|
| [Microsoft 365 Multi-Tenant Consolidation](01-m365-tenant-consolidation.md) | Consolidating three environments into one tenant — ~1,050 users, 809 mailboxes, 76.6 TB of data — across identity, Exchange, SharePoint, OneDrive, Teams, and endpoints |
| [Intune Enrollment Failure After Tenant Migration](02-intune-enrollment-after-migration.md) | Layer-by-layer diagnosis of devices that joined the new Entra tenant but silently failed MDM enrollment |
| [Safe Tenant-Wide Exchange Calendar Cleanup](03-exchange-calendar-cleanup.md) | Destructive automation done safely: discover → export → human approval → controlled execution |
| [SharePoint Stale "(Inactive)" Identity Cleanup](04-sharepoint-stale-identity-cleanup.md) | Site-level identity internals, PnP PowerShell, and the judgment to *not* bulk-delete 14,000+ stale entries |
| [Conditional Access Architecture & MFA Redesign](06-conditional-access-architecture.md) | Security design for a distributed workforce: dynamic groups, trusted locations, service-account exceptions, legacy auth lockdown |
| [Cloud Infrastructure & File-Service Modernization](07-cloud-infrastructure-modernization.md) | Moving distributed on-prem offices (DCs, file/print, ESXi, FortiGate) toward a cloud-first architecture |

## Troubleshooting Case Studies

Smaller in scope, but strong examples of diagnostic methodology.

| Case study | What it demonstrates |
|---|---|
| [Windows Hello Failure After Tenant Migration](08-windows-hello-after-migration.md) | Working down the stack — tenant state, NGC, PIN, biometrics, hardware — instead of repeating a failed fix |
| [Microsoft 365 License Migration with Atomic Pilot](09-license-migration-atomic-pilot.md) | Service-plan-level license analysis, a five-user pilot, and independent verification before scale |
| [Salesforce Console Tabs Causing Browser Instability](10-salesforce-console-tabs.md) | Refusing to accept "the browser crashes" as a root cause |

## Field Notes

Compact technical notes — narrower problems, still worth documenting.

| Note | Topic |
|---|---|
| [Salesforce DKIM and DNS Verification](11-salesforce-dkim-dns.md) | Selector-based DKIM coexistence between Salesforce and Microsoft 365 |
| [Teams Voice Audit and Number Reconciliation](12-teams-voice-audit.md) | Reconciling phone-number and emergency-address data between an inventory workbook and Teams |

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
