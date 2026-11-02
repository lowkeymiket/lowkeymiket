# Intune Endpoint Baseline and Cloud-Managed Workstation Standard

## What it is
A consistent Windows baseline covering identity, security, application deployment, user-data protection, and update/compliance behavior.

## How it works
The key design goal was to make the **desired endpoint state declarative**. A newly provisioned or replaced machine should converge toward the same baseline instead of being configured from technician memory.

The cloud-managed workstation model included:

- Microsoft Entra join during device setup;
- Windows Hello for Business enrollment;
- BitLocker / device-security requirements;
- Windows Update policy and compliance controls;
- OneDrive Known Folder Move for user-data protection;
- automatic sign-in / configuration of core Microsoft 365 workloads;
- deployment of required business applications through endpoint-management tooling;
- endpoint-security software deployment;
- post-migration validation of Entra registration versus actual MDM enrollment.

## Gotchas
One recurring lesson was that `AzureAdJoined : YES` is not sufficient evidence that device management is healthy. Entra registration and Intune enrollment are separate states and must be validated independently.

Windows Hello troubleshooting also required working below the GUI layer, including capability state, credential-container state, biometric components, and security-context inspection.

## Result
The endpoint model reduced manual workstation configuration and established a consistent cloud-managed baseline for identity, security, applications, user data, and updates.
