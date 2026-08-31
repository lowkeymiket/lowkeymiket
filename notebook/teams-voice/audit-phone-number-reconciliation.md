# Teams Voice Phone Number Reconciliation

## Problem

The source employee directory and the Microsoft Teams Phone assignment state had drifted apart. Some employees expected to have Teams Voice had no number in the source data, some had a number in the source but no matching Teams assignment, and others had conflicting phone values.

Manually checking more than a hundred voice-enabled users across HR data and Teams administration was slow and error-prone.

## Investigation

The historical audit produced a merge log that classified records into categories such as:

- Filled blank
- Updated existing value
- Already matched
- Phone not assigned in Teams
- User not found in Teams assignments
- No phone in source

The important design choice was to preserve the original and proposed values instead of silently overwriting contact data.

## Fix

This public reconstruction accepts two CSV exports:

1. The authoritative employee/source directory.
2. The current Teams Phone assignment export.

It normalizes phone numbers and display names, compares the two datasets, and generates a reconciliation report identifying matches, missing assignments, missing source values, and mismatches.

The output includes a `SuggestedPhone` field, but the script deliberately performs **no live Teams mutations**.

## Safety / Notes

- Read-only against Microsoft 365.
- Does not assign or remove phone numbers.
- Preserves both source and Teams values for human review.
- Normalizes common North American phone formats before comparing them.
- Flags every non-matching record for review.
- Separates data reconciliation from production change execution.

## Result

The historical workflow created a traceable merge log showing which users required corrections, which values were filled from the authoritative source, and which records already matched. This converted a messy telephony-data cleanup into a reviewable change set rather than a blind bulk update.

## Notes

**Public Reconstruction.** The historical reconciliation spreadsheets and merge log were recovered, but the exact original transformation script was not.
