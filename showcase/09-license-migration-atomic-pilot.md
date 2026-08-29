# Microsoft 365 License Migration with Atomic Pilot

## Executive summary

A licensing migration project required moving users between Microsoft 365 license families while avoiding accidental loss of services.

Rather than assuming two SKU names were functionally equivalent, the process inspected the underlying Microsoft **service plans** and tested the migration against a five-user pilot before any broader rollout.

## The problem

Microsoft 365 licensing names hide a second layer of configuration:

```
SKU
 |
 +-- Service Plan
 +-- Service Plan
 +-- Service Plan
 +-- Service Plan
```

Changing one SKU for another can affect Office activation, Exchange, Intune, Defender, Teams, SharePoint, and other entitlements. The risk grows dramatically when changing hundreds of users.

## Service-plan inspection

Instead of comparing license *names*, the service-plan IDs were queried. An actual inspection pattern from the pilot:

```powershell
$PlanIds = @(
    "43de0ff5-c92c-492b-9116-175376d08c38",
    "094e7854-93fc-4d55-b2c0-3ab5369ebdc1"
)

$Skus |
    ForEach-Object {

        $Sku = $_

        $_.ServicePlans |
            Where-Object ServicePlanId -in $PlanIds |
            Select-Object `
                @{N="Sku";E={$Sku.SkuPartNumber}},
                ServicePlanName,
                ServicePlanId,
                ProvisioningStatus
    } |
    Format-Table -AutoSize
```

This verified the presence and provisioning status of the underlying service plans — for example `OFFICESUBSCRIPTION` (`43de0ff5-c92c-492b-9116-175376d08c38`, a public Microsoft service-plan ID).

## Why this matters

Without inspecting plans, an administrator may reason:

> "Both licenses include Office."

But automation should reason:

> "Does the target SKU expose the exact service entitlement we require, and what is its provisioning state?"

## Pilot strategy

A small pilot cohort of five users was selected and the licensing operation was performed in a controlled, atomic fashion. A machine-readable result file recorded the pilot:

```
Pilot-Atomic-5-<timestamp>.csv
```

## Independent verification

Automation output was **not** treated as sufficient proof. Affected users were spot-checked in the Microsoft 365 Admin Center, providing independent confirmation that the resulting license state matched the scripted result.

## Rollout pattern

```
Understand Source SKU
        |
Understand Target SKU
        |
Compare Service Plans
        |
Build Migration Logic
        |
5-User Pilot
        |
Export Results
        |
Admin Center Verification
        |
Scale
```

## Technologies

Microsoft 365 licensing · Microsoft Graph / PowerShell · service plans · CSV reporting · Microsoft 365 Admin Center
