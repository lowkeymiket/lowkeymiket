# Salesforce SAML SSO with Microsoft Entra ID

## Executive summary

Implemented SAML-based Salesforce authentication using Microsoft Entra ID as the identity provider.

The project required understanding not just "SSO settings" but the complete authentication chain: federation identifiers, SAML metadata, certificates, user matching, MFA, Salesforce authentication policy, and troubleshooting failed assertions.

## Desired architecture

```
User
 |
 v
Microsoft Entra ID
 |
 |  MFA / Conditional Access
 v
SAML assertion
 |
 v
Salesforce
 |
 v
Mapped Salesforce User
```

## Components

- Entra Enterprise Application
- Salesforce SAML SSO configuration
- Federation IDs
- SAML metadata
- SAML signing certificate
- Salesforce user mapping
- Authentication policy
- MFA behavior

## Why SSO troubleshooting is difficult

From the user's perspective, every failure looks the same:

```
Unable to log in
```

But the actual failure can exist at many layers:

```
Entra Authentication
        |
SAML Assertion Generation
        |
Certificate Signature
        |
Salesforce SAML Configuration
        |
Federation ID
        |
Salesforce User
        |
Session Policy
```

## Troubleshooting approach

Failed SAML login attempts were reviewed to determine **which section of the chain** was failing:

| Category | Question |
|---|---|
| Identity provider failure | Did Microsoft authenticate the user? |
| Assertion failure | Did Entra generate an assertion containing the expected identity? |
| Certificate failure | Did Salesforce trust and validate the assertion signature? |
| User mapping failure | Did the Federation ID identify exactly one Salesforce user? |
| Salesforce policy failure | Did Salesforce accept the resulting session and authentication level? |

## Federation IDs

Salesforce Federation IDs were configured so the incoming Entra identity could map **deterministically** to the correct Salesforce account — preferable to hoping two unrelated identity systems happen to use the same display information.

## Certificate management

The SAML signing certificate was also rotated during the implementation. Certificate changes are particularly sensitive because:

```
Old IdP certificate  !=  Certificate Salesforce expects
```

A mismatch immediately breaks authentication for everyone.

## MFA

Once SSO was functioning, Microsoft MFA behavior was validated through the Salesforce login flow — making Microsoft Entra the primary authentication control plane for the application.

## Result

Salesforce SSO successfully authenticated through Microsoft Entra, with Microsoft MFA participating in the sign-in process and user mapping handled by Federation ID rather than coincidence.

## Technologies

Salesforce · Microsoft Entra ID · SAML 2.0 · Federation ID · X.509 certificates · MFA · Enterprise Applications
