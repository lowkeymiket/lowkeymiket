# Field Note: Teams Voice Audit and Number/Address Reconciliation

## Summary

Performed a Microsoft Teams Voice audit by comparing a source workbook against Teams Admin Center data to identify missing phone-number assignments and emergency-address discrepancies — a good example of turning a messy telephony audit into an actionable remediation list through data processing.

## Initial audit

The comparison identified approximately:

- **68 users** requiring phone-assignment attention
- **24 users** with emergency-address discrepancies

Output was organized into reporting tabs:

```
Needs Phone Assignment
Address Updates Needed
```

## The data-merge problem

The first report did not correctly carry all missing source phone numbers into the working dataset. The merge logic was corrected using the source phone value plus user identity/name matching. Final reconciliation:

```
68 Source Phone values merged

23 blank phone fields filled
23 existing values updated
22 already matched
 0 unmatched users
```

## Why this matters

Teams Voice provisioning has several pieces that must all agree:

```
User
 |
License
 |
Phone Number
 |
Emergency Location
 |
Calling Policy / Routing
```

A phone number existing in an inventory spreadsheet is not proof it is assigned correctly in Teams. Likewise, a working number does not prove the emergency location is correct — and emergency-address accuracy is a compliance issue, not just a data-quality one.

## Technologies

Microsoft Teams Phone · Teams Admin Center · Excel/CSV data processing · telephone-number assignment · emergency locations
