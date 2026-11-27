# DE-03 — Kloud Kart PostgreSQL Engineering Lab

AmaliTech DE-03 graded data engineering engagement.

## Current status — 25 November 2026

- PostgreSQL 18.7 environment provisioned.
- Maximum connections configured to 500.
- Learning and graded databases created separately.
- Original Evalu8 bundle received and inspected.
- Original file checksums verified against the local baseline.
- Learning database loaded and used for practice.
- Graded database loaded; all six tables reconciled with 822,832 records.
- Python connectivity to the graded database verified.
- Standalone graded Git repository initialized.
- Graded implementation and acceptance tests pending.

## Client requirements

Kloud Kart requires:

1. Safe concurrent order placement without overselling.
2. Fast customer spending and ranking reports.
3. Recursive low-stock reporting across nested categories.
4. An auditable record of stock movements.
5. Quantified data findings and defensible engineering decisions.
6. A client memo and an implemented additional improvement.

## Engineering approach

Understand the need → Gather evidence → Choose → Prove → Explain.

Significant architectural decisions are recorded as ADRs.
Smaller implementation decisions are recorded in working notes.

## Repository structure

| Directory | Purpose |
|---|---|
| sql/ | Reviewed SQL implementation |
| tests/ | Acceptance and regression tests |
| deliverables/ | Assessed documents and decisions |
| scripts/ | Setup and verification utilities |
| evidence/ | Sanitized execution and measurement evidence |
| working-notes/ | Assumptions, questions and working decisions |

## Local workspace separation

The graded repository is located inside a wider learning workspace.

- learning-path/: practice exercises and learning evidence.
- shared-data/: original Evalu8 bundle.
- graded-lab/: assessed work.
- .venv/: local Python environment.

The original bundle and learning workspace are outside this repository.
Obtain the original bundle through the authorized course source.

## Environment requirements

- Docker Engine or Docker Desktop.
- PostgreSQL 18 with max_connections=500.
- Python 3 and a virtual environment.
- Dependencies specified in requirements.txt.
- Original Evalu8 data and test bundle.

The local container is named kloudkart and publishes PostgreSQL
on 127.0.0.1:5432.

The learning database is kloudkart_learning.
The graded database is kloudkart_lab.

Both databases share one local PostgreSQL server.
Do not run learning workloads during graded performance measurements.

## Python dependencies

For a standalone clone:

    python3 -m venv .venv
    source .venv/bin/activate
    python -m pip install -r requirements.txt

An existing active virtual environment may also be used.

## Environment verification

With the PostgreSQL container running:

    bash scripts/check_setup.sh
    bash scripts/check_repo.sh

The setup verifier prompts for the local PostgreSQL password.

Optional connection configuration is supported through
DE03_DATABASE_BASE and PGPASSWORD.

Never commit actual credentials or local .env files.

## Original bundle

The supplied files must remain unchanged:

- schema.sql
- load.sql
- race_test.py
- data/categories.csv
- data/products.csv
- data/customers.csv
- data/orders.csv
- data/order_items.csv
- data/inventory_log.csv

The supplied race test must be executed without modification.

## Reproduction instructions

The complete fresh-load, implementation and acceptance-test
sequence will be documented as the graded work progresses.

Do not interpret environment verification as proof that the
graded implementation or acceptance tests have passed.

## Submission

Final file layout, repository destination and submission
requirements remain subject to the official Evalu8 instructions.

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

See `evidence/08_foreign_key_migration.txt` through `evidence/16_schema_integrity_test.txt`.

## Limitations

Schema protection does not independently prevent concurrent overselling, enforce category acyclicity or resolve historical exceptions.

Transaction-safe purchase processing is implemented separately in Stage 03.


## Stage 03 — Transaction-safe order placement

**Status:** Implemented and technically verified.

### Implementation

`sql/03_order_placement/01_place_order.sql`

Deploys the `place_order(bigint, bigint, integer)` function after the Stage 02 schema migrations.

The function uses an atomic conditional stock update under Read Committed isolation and creates the order, order item and inventory movement within the same transaction.

### Verification scripts

| File | Purpose |
|---|---|
| `tests/02_place_order_functional_test.sql` | Sequential purchase correctness and refusal handling |
| `tests/03_place_order_atomicity_test.sql` | Rollback following an injected inventory insertion failure |
| `tests/04_race_preflight.sql` | Database and fixture collision checks |
| `tests/05_race_cleanup_verification.sql` | Original race-test cleanup verification |
| `tests/06_inventory_audit_reconciliation.sql` | Detailed reconciliation of retained concurrent purchases |
| `tests/07_retained_audit_cleanup.sql` | Transactional removal of retained audit fixtures |
| `scripts/analyze_race_results.py` | Reproducible flash-sale latency and throughput analysis |

### Measured results

| Requirement | Result |
|---|---|
| Functional purchase tests | 11/11 passed |
| Failure atomicity assertions | 10/10 passed |
| Official concurrency scenarios | 4/4 passed |
| Last-unit race rounds | 25/25 passed |
| Flash-sale execution | 400 attempts in 1.89 seconds |
| Flash-sale outcomes | 50 successes, 350 refusals, zero errors |
| Independent purchase audit | 12/12 passed |
| Combined concurrency attempts | 475 |
| Combined concurrency outcomes | 85 successes, 390 refusals, zero errors |
| Historical baseline reconciliation | 822,832 records |
| Historical negative-stock anomalies preserved | 14 |

### Evidence and decisions

- `deliverables/decisions/ADR-002-atomic-conditional-stock-update.md`
- `deliverables/performance/order_placement_performance.md`
- `evidence/17_place_order_deployment.txt` through `evidence/27_retained_audit_cleanup.txt`

### Reproduction and safety

The supplied race-test harness must be obtained from the original lab resource bundle and executed only against an isolated graded database.

Run the fixture safety preflight before executing the harness.

The cleanup and audit verification scripts contain identifiers specific to the recorded test executions. Do not execute these scripts against a different run without verifying and adapting the fixture identifiers.

The retained audit cleanup script is not a schema migration and must not be included in an unconditional fresh-load deployment sequence.

Do not reset identifier sequences following testing.

The recorded performance benchmark represents one complete 400-buyer execution. Production performance and comparative locking performance remain unverified.

## Stage 05 — Inventory reporting and auditability

**Status:** Implemented and verified. Final fresh-load acceptance pending.

Implemented:

- Recursive low-stock category rollups with configurable thresholds.
- Arbitrary hierarchy depth and cycle protection.
- Separate reporting of uncategorised and unrooted products.
- Automatic auditing of changes to existing stock quantities.
- Atomic restock and correction routines.
- Sale audit integration with transaction-safe order placement.
- Stock-before, stock-after and database session user information.

### Verification

- E053: 11/11 correctness assertions passed.
- E056: 8/8 audit and atomicity assertions passed.
- E057: All four official race-test scenarios passed.
- Recursive rollup execution time: 1.461 ms.
- Flash sale: 400 buyers, 50 successful purchases, 350 refusals, zero errors, 2.10 seconds.

### Documentation

- [Inventory interfaces and deployment](sql/05_inventory/README.md)
- [ADR-005 — Recursive inventory reporting](deliverables/decisions/ADR-005-recursive-inventory-reporting.md)
- [ADR-006 — Stock movement audit](deliverables/decisions/ADR-006-stock-movement-audit.md)
- [Inventory and audit performance](deliverables/performance/inventory_audit_performance.md)