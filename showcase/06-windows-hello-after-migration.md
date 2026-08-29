# Windows Hello for Business Failure After Tenant Migration

## Executive summary

Windows Hello Face failed to enroll on a device that had recently transitioned between Microsoft Entra tenants.

Several reasonable identity and credential fixes failed. Instead of repeating them indefinitely, the investigation moved **down the stack**, using alternate biometric hardware to demonstrate that the general Windows Hello identity configuration was functional and isolate the fault to the biometric layer.

The final fix was unexpected: enabling the Windows setting that allows Windows Hello to use an **external camera or fingerprint sensor**. Flipping that toggle re-initialized the biometric stack, and Windows Hello Face enrollment then completed **on the built-in camera that had been failing all along**. The toggle's documented purpose had nothing to do with the problem. What mattered was the side effect.

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

## Resolution: a settings toggle

Testing external hardware required enabling a Windows setting:

```
Settings > Accounts > Sign-in options
    "Sign in with an external camera or fingerprint reader"
```

After that toggle was enabled, Windows Hello Face **enrollment completed on the built-in webcam**, the same sensor that had failed every previous attempt. The toggle exists to control external biometric devices, yet flipping it fixed the internal one.

## Why a toggle fixed a biometric failure

Microsoft does not document the toggle's internals, so this is an evidence-based hypothesis rather than a verified mechanism. But the evidence lines up well:

1. Windows Hello biometrics run through the **Windows Biometric Framework** (the Windows Biometric Service), which keeps its own sensor configuration and per-sensor template databases. This layer sits below NGC, the PIN, and the Entra join, and none of the earlier resets touch it.
2. That is consistent with what the investigation found in Layer 4: expected **BioEnrollment / WinBioDatabase state was absent** on this device.
3. Biometric configuration is bound to the **user's identity**. This device had crossed Entra tenants, giving the user a new identity while the biometric layer retained state associated with the old one. The face enrollment path was stuck referencing stale per-identity state.
4. The external-sensor toggle changes which **sensor pool** Windows Hello may use. Flipping it forces the biometric service to re-enumerate biometric units and rebuild its sensor configuration, recreating the missing database state fresh. The re-enumeration can also make the camera driver reinitialize, which is why the fix looked like a driver or firmware event from the outside.

In effect, the toggle acted as an accidental **reset button for the biometric stack**: the one remaining suspect layer, reset by a setting whose documented purpose is something else entirely.

This also settles the root cause. The fault was never the camera hardware, and the proof is that the **same built-in webcam enrolled successfully** the moment the surrounding state was rebuilt. The real fault was per-identity biometric state orphaned by the tenant migration, the same class of problem as the [Intune enrollment failure](02-intune-enrollment-after-migration.md): every component individually healthy, with the breakage living in state left behind between them.

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

Windows 11 · Windows Hello for Business · Microsoft Entra ID · NGC · Windows Biometric Framework · Windows Biometric Service · device migration
