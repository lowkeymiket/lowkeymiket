# Intune Endpoint Baseline and Cloud-Managed Workstation Standard

## Problem
As infrastructure moved toward Microsoft 365 and cloud identity, workstation deployment needed to become repeatable without depending on an administrator manually configuring every PC after delivery.

The target was a consistent Windows baseline covering identity, security, application deployment, user-data protection, and update/compliance behavior.

## Endpoint Baseline
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

## Fix
The key design goal was to make the **desired endpoint state declarative**. A newly provisioned or replaced machine should converge toward the same baseline instead of being configured from technician memory.

Identity enrollment, data redirection, application deployment, encryption, Windows Hello, and updates were therefore treated as parts of one workstation architecture rather than unrelated setup tasks.

## Troubleshooting / Production Lessons
One recurring lesson was that `AzureAdJoined : YES` is not sufficient evidence that device management is healthy. Entra registration and Intune enrollment are separate states and must be validated independently. That distinction later became the basis of a dedicated post-migration validation utility in this repository.

Windows Hello troubleshooting also required working below the GUI layer, including capability state, credential-container state, biometric components, and security-context inspection.

## Result
The endpoint model reduced manual workstation configuration and established a consistent cloud-managed baseline for identity, security, applications, user data, and updates.

## Notes
**History-backed architecture write-up.** Production policy exports were not recovered in a publishable form. Related diagnostic and validation scripts elsewhere in this repository are backed by recovered execution evidence.
