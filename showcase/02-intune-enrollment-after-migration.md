# Diagnosing Intune Enrollment Failure After Tenant Migration

## Executive summary

After a Windows endpoint migration, devices could appear to be successfully joined to the destination Microsoft Entra tenant while still being **completely unmanaged** by the destination Intune environment.

This incident became a deeper investigation into the distinction between **identity registration** and **device management enrollment** — two things that look like one checkbox from the portal, but are entirely separate machine states.

## Symptom

At first glance the migrated machine looked successful:

```
dsregcmd /status
```

```
AzureAdJoined : YES
```

The device existed in the destination tenant. The user could authenticate. But the actual management state looked like this:

```
Entra:    Device exists
Windows:  AzureAdJoined = YES
Intune:   No managed device
MDM:      NONE
```

## Why this was dangerous

This is a particularly subtle migration failure because the user may not notice anything wrong. The machine can still boot, authenticate, access Microsoft 365, run Office, and browse the web.

But IT no longer controls:

- BitLocker
- Compliance
- Defender configuration
- Application deployment
- Windows Update policy
- Configuration profiles
- Security baselines
- Endpoint restrictions

**A visibly failed migration is easy to detect. A partially successful migration is much more dangerous.**

## Investigation

### Layer 1: Entra join

First, verify the machine actually belongs to the destination tenant. `dsregcmd /status` provides join state, tenant information, device identity, the Primary Refresh Token, and MDM discovery values.

The Entra portion appeared healthy — which immediately narrowed the problem.

### Layer 2: User eligibility

The user was checked for Intune licensing, MDM enrollment scope, authentication, and destination identity. No user-eligibility problem explained the failure.

### Layer 3: Windows MDM state

Windows normally creates scheduled tasks associated with MDM enrollment:

```powershell
Get-ScheduledTask |
    Where-Object {
        $_.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*"
    } |
    Select-Object TaskName, TaskPath, State
```

The expected destination enrollment structure was **missing** — a much stronger indicator than anything visible on the Entra device object.

### Layer 4: Event logs

Device-management event logs were reviewed to answer one question:

> Did Windows actually attempt and complete an MDM enrollment after migration?

There was no convincing evidence that it had.

### Layer 5: Quest migration state

Attention moved back into the migration tooling. The endpoint migration package had performed part of its job:

```
Quest migration
      |
      +-- Entra transition        SUCCESS
      |
      +-- Intune enrollment       FAILURE / NOT COMPLETED
```

Investigation areas included package configuration, project configuration, endpoint registration, migration sequencing, stale enrollment artifacts, agent context, and MDM auto-enrollment triggering.

### Known-good comparison

Instead of continuing to troubleshoot the broken device in isolation, a *successfully* migrated endpoint became the comparison point:

```
Broken Device        Known-Good Device
-------------        -----------------
Entra joined         Entra joined
PRT                  PRT
MDM URLs             MDM URLs
EnterpriseMgmt?      EnterpriseMgmt?
Event logs           Event logs
Intune object        Intune object
Quest state          Quest state
```

Comparing against a known-good peer is often much faster than trying to reconstruct "normal" from documentation.

## Core lesson

```
AzureAdJoined : YES
```

does **not** mean

```
Intune enrollment succeeded
```

These must be validated independently.

## Reusable diagnostic flow

```
1. dsregcmd /status
        |
2. Verify tenant
        |
3. Verify PRT
        |
4. Verify user license / MDM scope
        |
5. Inspect EnterpriseMgmt scheduled tasks
        |
6. Inspect MDM event logs
        |
7. Check Intune portal
        |
8. Compare known-good endpoint
        |
9. Inspect migration-tool state
```

## Technologies

Microsoft Intune · Microsoft Entra ID · Windows 11 · Quest ODM / Device Migration · PowerShell · `dsregcmd` · Windows Task Scheduler · Event Viewer
