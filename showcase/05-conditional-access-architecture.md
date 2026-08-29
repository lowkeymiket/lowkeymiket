# Conditional Access Architecture and MFA Redesign

## Executive summary

Designed and modified Microsoft Entra Conditional Access behavior across a distributed workforce.

The goal was not merely "turn MFA on." The actual challenge was enforcing the correct authentication posture while accounting for employees, service accounts, remote work, trusted offices, geographic restrictions, legacy authentication, and specialized workflows.

## Identity population

An "Active Employees" **dynamic group** served as an important security boundary. Employee ID formed part of the membership logic, allowing actual employees to be treated differently from:

- Service accounts
- Integrations
- Utility identities
- Other non-human accounts

This also connected identity lifecycle automation directly to access policy.

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

MFA enforcement became consistent and aligned with the intended location model, while service workflows and justified legacy exceptions kept working — deliberately, narrowly, and documented.

## Technologies

Microsoft Entra ID · Conditional Access · Entra P2 · MFA · Dynamic Groups · Named Locations · Microsoft Authenticator · Exchange Online
