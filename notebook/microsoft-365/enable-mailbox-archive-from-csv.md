# Enable Exchange Online Archive Mailboxes from CSV

## Problem
A migration/licensing workflow identified mailboxes that needed online archives enabled. Doing this manually in the Microsoft 365 admin interfaces was slow and error-prone, especially when the target list already existed in CSV form.

## Fix
Use Exchange Online PowerShell to import a reviewed CSV, inspect each mailbox's current archive state, enable the archive only when needed, and export a per-user result log.

## Safety / Notes
- Supports `-WhatIf` through `ShouldProcess`.
- Skips blank identities.
- Checks whether the archive is already active before making a change.
- Re-queries the mailbox after the operation to verify state.
- Captures failures per mailbox rather than terminating the batch.

## Result
The historical workflow produced a working CSV-driven archive-enablement template for Exchange Online administration. The public version here is hardened and sanitized.
