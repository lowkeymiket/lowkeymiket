# Bulk Entra Employee ID Update

## Problem
Employee IDs needed to be populated or corrected in Entra ID in bulk from a reviewed CSV rather than edited manually one user at a time. The process also had to avoid changing users whose attributes were mastered by on-premises Active Directory.

## Fix
A Microsoft Graph PowerShell script imports a CSV, validates each row, looks up the user, checks whether the account is directory-synchronized, and updates `employeeId` only for cloud-managed users.

## Safety / Notes
- `-DryRun` mode records what would change without modifying Entra ID.
- Missing UPN or employee ID rows are skipped and logged.
- Employee IDs longer than the supported length are rejected.
- Synced users are explicitly skipped so the source directory remains authoritative.
- Every user receives a structured result row with status and notes.

## Result
The workflow turned a repetitive directory-maintenance task into a reviewable bulk operation with an audit CSV and clear handling for exceptions.

## Notes
**Recovered exact source.** The publishable copy removes organization-specific input data but preserves the original script logic.
