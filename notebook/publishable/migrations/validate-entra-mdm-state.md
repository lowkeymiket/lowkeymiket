# Validate Entra Join and MDM State After Migration

## Problem

During tenant-consolidation testing, a workstation could be successfully joined to the target Microsoft Entra tenant while still not being managed by Intune. Treating those states as equivalent would create a false-positive migration result: identity could look correct while compliance, application deployment, security policy, and configuration management were still missing.

## Investigation

We used `dsregcmd /status` and the Entra/Intune management portals to separate device-registration state from MDM enrollment state. Recovered evidence shows a migrated workstation reporting `AzureAdJoined : YES` and `DeviceAuthStatus : SUCCESS`, while separate Intune configuration work was still required.

## Fix

This public reconstruction turns those checks into a reusable validation script. It records:

- Entra join state;
- domain / enterprise join state;
- device authentication status;
- tenant identity;
- MDM URLs advertised to the device; and
- Windows enrollment-registry indicators.

It warns when Entra join is absent, device authentication is unhealthy, or there are no obvious MDM enrollment indicators.

## Safety / Notes

The script is completely read-only. It deliberately does not attempt automatic enrollment because the correct remediation depends on tenant MDM scope, licensing, enrollment restrictions, Conditional Access, device ownership, and migration tooling.

## Result

The diagnostic approach prevented a successful Entra join from being incorrectly treated as a complete endpoint migration. That distinction is important during large tenant cutovers because identity, Office profile transition, OneDrive transition, and MDM enrollment can succeed or fail independently.
