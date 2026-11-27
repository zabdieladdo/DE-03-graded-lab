# Original Schema Findings

Date: 2026-11-25

Database: kloudkart_lab

Evidence:
- sql/01_diagnosis/01_schema_inspection.sql
- evidence/01_schema_inspection.txt

## Observed facts

- Six tables and 31 columns.
- Six primary keys.
- Six NOT NULL constraints on primary key columns.
- All 25 non-primary-key columns permit NULL.
- No foreign keys.
- No CHECK constraints.
- No additional unique constraints.
- Six primary key indexes.
- No secondary indexes.
- No public triggers observed.

## Interpretation

The database enforces record identity but does not enforce
most relationships or business value rules.

Missing constraints indicate exposure to integrity problems.
They do not establish that existing records are defective.

The absence of triggers does not prove that inventory logging
or transaction protection is absent from application code.

## Initial engineering position

Business value validation deserves high priority because
customer service, inventory management and financial reporting
depend on accurate and consistent data.

Strongest counterargument:
Transaction safety can prevent immediate customer-facing harm
even when the starting data is completely valid.

This was the initial position; the subsequent diagnosis prioritised transaction safety.

## Outstanding investigations

- Referential integrity.
- Business value validity.
- Financial exposure.
- Category hierarchy integrity.
- Inventory movement consistency.
- Transaction safety.
- Reporting performance.

## Subsequent implementation

Six foreign keys (two validated), five CHECK constraints (three validated), three identity columns, transaction-safe purchase and movement audit were implemented. Historical exceptions remain. The original inspection above is not a description of the migrated schema. See [ADR-001](../decisions/ADR-001-preserve-historical-records.md), [diagnosis](../diagnosis/data_findings.md) and evidence 08–16, 55–57.
