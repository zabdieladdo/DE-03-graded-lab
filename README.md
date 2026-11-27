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

# Stage 04 — Customer spending reports

## Status

Implemented and functionally verified. Final performance acceptance and fresh-load verification pending. See ADR-003, ADR-004 and `deliverables/performance/customer_reporting_performance.md` from repository root. E051 is optional and deferred; it is not a deployment dependency.

## Deployment order

After the official baseline load and Stages 02–03, execute only these definition scripts, in order, with psql `ON_ERROR_STOP=1` against `kloudkart_lab`:

1. `03_reporting_foundation.sql`
2. `04_customer_spending_summary.sql`
3. `08_customer_monthly_spending.sql`
4. `12_customer_running_spending.sql`
5. `16_customer_ranking.sql`

Check these filenames against the actual checkout before finalizing the master runner. Investigation, inspection and benchmark scripts are not deployment scripts. Do not reload or drop the current working database just to close this stage.

## Interfaces

All functions are in `public`. Date parameters are explicit; use finite dates. Ranking basis defaults to `trailing_12_months`; alternative `recorded_history`.

| Interface | Purpose |
|---|---|
| `v_orders_normalized`, `v_eligible_orders` | Shared status and eligibility rules |
| `eligible_orders_as_of(date)` | Eligible orders through cutoff |
| `reporting_date_exceptions(date)`, `v_future_dated_orders` | Date exceptions |
| `customer_spending_summary(date)` | All current customers, recorded spending and counts |
| `spending_reconciliation(date)` | Eligible, attributed and unattributed totals |
| `monthly_reporting_metadata(date)` | Window, partial month and coverage warning |
| `customer_monthly_spending_sparse(date)` | Active customer-months |
| `customer_monthly_spending(date)` | Dense 12-month calendar |
| `customer_monthly_spending_wide(date)` | Wide monthly export |
| `customer_monthly_running_spending(date)` | Monthly values, opening and running balances |
| `customer_order_running_spending(date)` | Transaction-level running balances |
| `customer_spending_totals(date)` | History, opening and window totals |
| `customer_spending_ranked(date,text)` | Full qualifying population with ranks |
| `customer_top100(date,text)` | Up to 100 selected customers |
| `customer_top100_metadata(date,text)` | Cutoff ties and ranking reconciliation |

## Run the core report

Run in psql, not Bash. For the supplied baseline use the headline date; for other reports select an appropriate cutoff. Explicit outer ordering is required for ordered output. These statements return actual report rows; E050 instead discards CSV output to measure local transfer.

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT * FROM public.customer_spending_summary(DATE '2026-08-31') ORDER BY customer_id;
SELECT * FROM public.customer_monthly_running_spending(DATE '2026-08-31') ORDER BY customer_id, order_month;
SELECT * FROM public.customer_top100(DATE '2026-08-31') ORDER BY ranking_position;
SELECT * FROM public.customer_top100_metadata(DATE '2026-08-31');
SELECT * FROM public.spending_reconciliation(DATE '2026-08-31');
SELECT * FROM public.monthly_reporting_metadata(DATE '2026-08-31');
ROLLBACK;
```

For large outputs use CSV export rather than printing hundreds of thousands of rows in a terminal. Persistent file delivery is not measured by E050.

## Verification

Run the existing reporting tests in order after deployment, using `psql -X -v ON_ERROR_STOP=1 -f` and retain evidence. These were executed on the graded database; repeat as part of final fresh-load verification, not as a new closeout experiment.

| Test | Evidence checkpoint | Observed PASS notices |
|---|---|---:|
| `tests/08_reporting_foundation_test.sql` | E031 | 17 |
| `tests/09_customer_spending_summary_test.sql` | E033 | 20 |
| `tests/10_customer_monthly_spending_test.sql` (revision 3) | E038 | 21 |
| `tests/11_customer_running_spending_test.sql` | E043 | 22 |
| `tests/12_customer_ranking_test.sql` | E047 | 49 |
| `sql/04_reporting/20_monday_report_integration.sql` | E050 | 6 |

Headline reference: 40,420 customers; 111,190 attributed eligible history orders, GHS 339,176,836.88; 144 unattributed eligible orders, GHS 388,780.89; 485,040 monthly rows; window spending GHS 334,634,759.00; top-100 window spending GHS 14,781,340.27. These are baseline-specific, not hardcoded business rules.

## Remaining work

E050 headline median 5.372 s, worst 5.929 s; all four runs exceed provisional 5 s. Retain A as working reference. E051/B1, B2/B3, growth testing and persistent precomputation deferred; concurrent checkout/report and fresh-load verification remain pending. No measured historical forty-minute comparison. See performance report for methods and caveats.



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

## Stage 06 — Integrated performance verification

**Status:** Latest current-volume performance gates passed. Final fresh-load acceptance pending.

Verified reporting and checkout activity running concurrently on the existing database server.

### Results

- Isolated customer report: 3.487 seconds.
- Concurrent customer report: 4.227 seconds.
- Flash sale: 400 attempts in 2.05 seconds.
- Successful purchases: 50.
- Correct refusals: 350.
- Overselling and unexpected errors: zero.
- Observed workload overlap: 19 samples.
- Baseline table counts restored and no remaining race fixtures.

Earlier reporting measurements exceeded the provisional five-second target. The latest results demonstrate feasibility at current volume, not a guaranteed production latency.

### Documentation

- [Integrated performance report](deliverables/performance/integrated_workload_performance.md)
- [Reporting architecture decision](deliverables/decisions/ADR-004-reporting-architecture.md)
- [Performance verification instructions](sql/06_optimization/README.md)