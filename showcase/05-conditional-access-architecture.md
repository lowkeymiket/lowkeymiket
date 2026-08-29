# Conditional Access Architecture and MFA Redesign

## Executive summary

Designed and modified Microsoft Entra Conditional Access behavior across a distributed workforce.

The goal was not merely "turn MFA on." The actual challenge was enforcing the correct authentication posture while accounting for employees, service accounts, remote work, trusted offices, geographic restrictions, legacy authentication, and specialized workflows.

The centerpiece is a **three-tier access model driven entirely by identity attributes**: active employees get the full policy set, separated employees keep access to exactly one application, and special-purpose bypass accounts live outside the employee posture under their own rules. Nobody manages these tiers by hand.

## The identity boundary: one dynamic group

The core of the design is a **dynamic security group**, `~Active Employees`, whose membership is computed from identity attributes rather than maintained by hand. Conditional Access is then applied to everyone in this group.

Conceptually, membership requires all of the following (domain sanitized):

```
user.userPrincipalName  ends with   "@company.example"
user.userPrincipalName  not contain "EXT"
user.employeeId         is present
user.displayName        not contain "(Inactive)"
user.displayName        not contain "(Bypass)"
```

Each condition earns its place:

| Condition | What it excludes |
|---|---|
| Company UPN suffix | Guests and accounts from other domains |
| No `EXT` in the username | External users |
| Employee ID present | Service accounts, integrations, and utility identities, which never get one |
| No `(Inactive)` in display name | Separated employees |
| No `(Bypass)` in display name | Special-purpose access accounts (below) |

Nobody adds users to this group. Identity lifecycle data **is** the membership: hire someone and populate their attributes correctly, and they fall into the employee security posture automatically. The same is true in reverse, which is where the design gets interesting.

## Access tiers driven by lifecycle convention

The display-name markers are not cosmetic. They drive a three-tier access model:

```
Active employee
    displayName: "Jane Doe"
    -> In ~Active Employees
    -> Full application access, MFA and location policy enforced

Separated employee
    displayName: "Jane Doe (Inactive)"
    -> Out of ~Active Employees
    -> Conditional Access allows ONE application:
       Wellable, the HR wellness platform
    -> Everything else is blocked

Access-bypass account
    displayName: "Jane Doe (Bypass)"
    -> Out of ~Active Employees
    -> Used internally for manager/HR access to a
       separated employee's account, under its own rules
```

The `(Inactive)` tier exists because separation is not always all-or-nothing: former employees retain access to exactly one HR benefit application, and nothing else. Rather than maintaining a separate allowlist, the blocking policy simply targets `(Inactive)` users for everything except that app.

The practical effect is that **offboarding is an attribute change, not a policy change**. Renaming a display name to `(Inactive)` instantly removes the user from the employee posture and drops them into the restricted tier, with no Conditional Access policy edited and no group membership touched by hand.

The trade-off is equally real and worth stating: in this design, identity data quality *is* access policy. A display-name convention carrying security weight demands disciplined naming, because the same string that renders in a people picker also decides which Conditional Access tier a person lands in. That discipline leaking into other systems is exactly what the [SharePoint stale identity case study](04-sharepoint-stale-identity-cleanup.md) is about: SharePoint cached `(Inactive)` display names beyond their lifecycle, and the cached copies outlived the state they described.

## Objectives

```
Active employee
      |
      +-- Require MFA
      |
      +-- Block inappropriate geography
      |
      +-- Trusted office exception
      |
      +-- Preserve required service workflows
```

## Trusted location fix

The corporate headquarters office was configured as a trusted named location. One policy had a location condition that was not producing the intended enforcement, so its location scope was changed to:

```
Any network or location
```

with the trusted location handled through **exclusions** instead. This produced far more predictable MFA enforcement.

## Why Conditional Access is easy to misread

A policy's result is not determined by one dropdown. Effective access is closer to:

```
User Scope
  x
Application Scope
  x
Location
  x
Device State
  x
Authentication Strength
  x
Grant Controls
  x
Exclusions
```

…with multiple policies interacting simultaneously.

## Service accounts

Service accounts required particular care: forcing normal interactive MFA onto non-interactive integrations simply breaks business processes. Exceptions therefore had to be:

- Intentional
- Narrow
- Documented
- Separated from employee policy

## Legacy authentication

Legacy authentication was also reviewed. A legacy-auth blocking policy was first run in **report-only mode** while its effects were evaluated.

Related work included broadly disabling SMTP AUTH while preserving narrow exceptions where a legitimate legacy device or workflow still needed it. The security posture was:

```
Disabled by default
        +
Explicit exception only where justified
```

rather than:

```
Leave insecure feature enabled globally
because something might need it
```

## Result

MFA enforcement became consistent and aligned with the intended location model, while service workflows and justified legacy exceptions kept working: deliberately, narrowly, and documented.

## Technologies

Microsoft Entra ID · Conditional Access · Entra P2 · MFA · Dynamic Groups · Named Locations · Microsoft Authenticator · Exchange Online
