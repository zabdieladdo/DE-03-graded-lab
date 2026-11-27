# Stage 02 — Schema Protection

## Objective

Prevent new relational and numerical integrity violations while preserving historical records and enabling concurrency-safe identifier allocation.

## Migration order

| Script | Purpose |
|---|---|
| `01_foreign_keys.sql` | Introduce six foreign keys |
| `02_value_constraints.sql` | Introduce five essential numerical constraints |
| `03_identifier_generation.sql` | Enable automatic identifiers for purchases |

Run these migrations in the stated order against a freshly loaded baseline. Each migration is transactional and intended for one-time execution.

## Verification scripts

| Script | Purpose |
|---|---|
| `04_verify_foreign_keys.sql` | Verify foreign key definitions |
| `05_verify_value_constraints.sql` | Verify numerical constraints and historical exceptions |
| `06_inspect_identifiers.sql` | Inspect identifier ranges before migration 03 |
| `07_verify_identifiers.sql` | Verify identity configuration |

## Engineering decisions

- D021: Preserve historical orphan references while preventing new broken references.
- D022: Enforce essential numerical values without imposing unconfirmed business rules.
- D023: Use PostgreSQL identity columns for automatic identifier allocation.

## Historical exceptions

The migrations preserve:

- 1,023 historical orphan references.
- 14 negative-stock products.
- 148 order items with missing prices.
- Existing identifiers and legitimate zero values.

Historical exceptions require evidence-based resolution rather than automatic correction.

## Verification results

- Six foreign keys: two validated, four initially unvalidated.
- Five CHECK constraints: three validated, two initially unvalidated.
- Three identity columns.
- All 24 functional checks passed.
- All six baseline table counts reconciled.
- Total historical records: 822,832.

## Regression testing

Run `tests/01_schema_integrity_test.sql` after all three migrations.

Test record changes are rolled back. Sequence allocations are not rolled back.

## Evidence

See `evidence/06_safety_and_recovery.txt (original: 08_foreign_key_migration.txt; lines 7-24)` through `evidence/06_safety_and_recovery.txt (original: 16_schema_integrity_test.txt; lines 256-309)`.

## Limitations

Schema protection does not independently prevent concurrent overselling, enforce category acyclicity or resolve historical exceptions.

Transaction-safe purchase processing is implemented separately in Stage 03.