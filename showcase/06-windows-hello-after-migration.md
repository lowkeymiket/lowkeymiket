# Windows Hello for Business Failure After Tenant Migration

## Executive summary

Windows Hello Face failed to enroll on a device that had recently transitioned between Microsoft Entra tenants.

Several reasonable identity and credential fixes failed. Instead of repeating them indefinitely, the investigation moved **down the stack** until alternate biometric hardware demonstrated that the general Windows Hello identity configuration was functional — isolating the fault to the original biometric path.

## Initial theory

Because the computer had crossed tenants, stale credential state was the logical first suspect.

## Layer 1: Entra identity

Current join state was inspected:

```
dsregcmd /status
```

Old tenant authentication information was removed where applicable.

## Layer 2: Windows Hello credential store (NGC)

The NGC credential store was investigated:

```powershell
Get-ChildItem `
    "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Microsoft\Ngc" `
    -Force
```

The existing NGC state was reset and recreated.

## Layer 3: PIN

The Windows Hello PIN was reprovisioned. **The problem remained.**

This mattered: the troubleshooting tree had now eliminated several likely causes rather than confirming any of them.

## Layer 4: Biometrics

Expected biometric directories and components were inspected. Some expected BioEnrollment / WinBioDatabase state was absent. Logs were gathered.

## Layer 5: Hardware test

Alternate biometric hardware was introduced. Windows Hello provisioning **succeeded** using an external camera/fingerprint reader.

That changed the diagnosis: the general identity and Hello stack could clearly complete enrollment. The remaining problem was much more likely tied to the original device's biometric path.

## Diagnostic progression

```
Tenant State
    |
NGC Credentials
    |
PIN
    |
Biometric Stack
    |
Hardware
```

## What made this good troubleshooting

A common mistake looks like this:

```
NGC reset didn't work
        |
Do NGC reset again
```

Instead:

```
NGC reset didn't work
        |
That hypothesis lost probability
        |
Move to the next layer
```

Each failed fix was treated as *evidence* that narrowed the search, not as an invitation to repeat it harder.

## Technologies

Windows 11 · Windows Hello for Business · Microsoft Entra ID · NGC · Windows Biometric Framework · device migration
