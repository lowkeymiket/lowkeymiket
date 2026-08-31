# Atomic Microsoft 365 License Migration

## Problem
A large group of users needed to move from one Microsoft 365 license SKU to another without temporarily losing services such as Office, Exchange, or other overlapping service plans. A small pilot had to be validated before running the full batch.

## Fix
The migration pattern adds the destination license first, verifies the assignment, and only then removes the source license. CSV input makes the operation repeatable and allows pilot and production batches to use the same logic.

## Safety / Notes
- Destination-first assignment prevents a licensing gap.
- SKU availability is checked before migration.
- Pilot users can be run independently before the full population.
- Per-user success/failure results are written to CSV.
- Source license removal occurs only after destination assignment succeeds.

## Result
The pilot migration completed successfully and was spot-checked in the Microsoft 365 Admin Center before proceeding to the full batch.

## Notes
**Reconstructed public version.** The production workflow and sequence are historical; this sanitized script represents the same operational design without tenant-specific SKU IDs or user data.
