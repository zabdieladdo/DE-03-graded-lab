# DE-03 — Kloud Kart PostgreSQL engineering lab

## Purpose and status
Prevent overselling, provide customer spending and nested low-stock reports, and record stock movements. The additional improvement checks publication readiness. Implementation and local tests completed within their stated scopes; final fresh-load acceptance, successful November publication retry and HTML interfaces remain pending. No production guarantee or approved materiality limits.

## Deliverables
| Deliverable | Location |
|---|---|
| Diagnosis | [Data findings](deliverables/diagnosis/data_findings.md) |
| Working SQL | `sql/` and `tests/` |
| Decisions | `deliverables/decisions/` (ADR-001–007) |
| Client memo | [Memo](deliverables/memo/client_memo.md) |
| Improvement | [Publication readiness](deliverables/improvement/improvement.md) |
| Performance | `deliverables/performance/` |
| Supporting investigation | `deliverables/supporting/` |
| Traceability | [Evidence index](deliverables/EVIDENCE_INDEX.md), `evidence/` |

## Environment
Local Windows/WSL2 Ubuntu, Docker PostgreSQL 18 (observed 18.7), 500 connections for race tests, Python with psycopg2. Existing container `kloudkart`, project root mounted at `/workspace`, host port 5432 bound to loopback. Keep the supplied `schema.sql`, `load.sql`, `race_test.py` and data under sibling `shared-data/`; do not commit raw customer data. Use a disposable `kloudkart_lab` database, never production. Some setup checks also expect `kloudkart_learning`.

**Run in terminal:**
```bash
cd ~/projects/de03-kloudkart/graded-lab
source ../.venv/bin/activate
python -m pip install -r requirements.txt
bash scripts/check_setup.sh
```

Configure the connection without printing the password:
```bash
export DATABASE_URL="$(python -c 'from getpass import getpass; from urllib.parse import quote; print("postgresql://postgres:"+quote(getpass("PostgreSQL password: "),safe="")+"@127.0.0.1:5432/kloudkart_lab")')"
```

## Fresh-load deployment order
The supplied schema is destructive. Back up the current lab and confirm the disposable target before loading; do not run against an existing working database without explicit approval. Use the original supplied bundle unchanged. The following is the ordered migration list **after** successful baseline load (94 categories, 4,023 products, 40,420 customers, 159,384 orders, 336,559 items, 282,352 movements; total 822,832).

1. `sql/02_schema/01_foreign_keys.sql`
2. `sql/02_schema/02_value_constraints.sql`
3. `sql/02_schema/03_identifier_generation.sql`
4. `sql/03_order_placement/01_place_order.sql`
5. `sql/04_reporting/03_reporting_foundation.sql`
6. `sql/04_reporting/04_customer_spending_summary.sql`
7. `sql/04_reporting/08_customer_monthly_spending.sql`
8. `sql/04_reporting/12_customer_running_spending.sql`
9. `sql/04_reporting/16_customer_ranking.sql`
10. `sql/05_inventory/01_low_stock_rollup.sql`
11. `sql/05_inventory/02_stock_movement_audit.sql`

Execute each file once with `psql -X -v ON_ERROR_STOP=1` and stop on failure. Example, **run in terminal** after baseline load:
```bash
docker exec -i kloudkart psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 -f /workspace/graded-lab/sql/02_schema/01_foreign_keys.sql
```

Investigation, verification and performance SQL are not migrations. Reference SQL in `sql/07_improvement/` is executed through Python, not directly through psql.

## Verification order
Run schema test 01 after schema migrations; purchase tests 02–03 after original purchase definition and **before** replacing it with the audit implementation. Test 03 injects a failure into the original log path. Run reporting tests 08–12 after reporting definitions; inventory tests 13–14 after inventory definitions. Use `tests/04_race_preflight.sql` before the official harness, `tests/05_race_cleanup_verification.sql` afterwards. Tests 06–07 are specific to historical retained fixtures, not generic fresh-load tests; do not run blindly. Run the unmodified official harness with `python ../shared-data/race_test.py --verbose` and no keep-fixtures flag. Run `python -u tests/test_report_readiness.py` and `python -u scripts/probe_readiness_reference.py`. Capture exit codes and new evidence; preserve old logs. Final acceptance runner and exact fresh-load transcript still pending.

## Report interfaces
See [reporting README](sql/04_reporting/README.md) for functions and semantics. Completed-only eligibility; explicit inclusive cutoff, trailing 12 calendar months, all current customer accounts, deterministic top 100. Recorded header totals are not verified cash revenue; currency unconfirmed. Low stock threshold 10 is configurable and provisional. Inventory audit covers new stock changes, not historical opening balances.

**Run in terminal:**
```bash
set -o pipefail
python -u scripts/generate_monday_report.py --as-of 2026-08-31
python -u scripts/generate_monday_report.py --as-of 2026-11-26
unset DATABASE_URL
```
Run separately and inspect exit codes. PASS/WARN exit 0, FAIL exit 2, ERROR exit 3. WARN requires review and disclosure; no automatic release. Generated private CSV/JSON files are ignored; do not commit or share them. Policy thresholds are proposed. August verified WARN; November reference passed but publication and integrity evidence currently fail. Zero-eligible informational entry remains an implementation gap.

## Measured results and limitations
Official race tests passed; 400 attempts/50 wins/350 refusals, zero errors in tested runs. Integrated SQL workload 3.487 s solo and 4.227 s concurrent in later trials, earlier four runs missed provisional 5 s. Verified publication median 13.933 s (three runs), approximately 962 MiB Python RSS. No agreed full-publication SLA. Isolated locking comparison passed 12 trials; not a full purchase benchmark. See performance reports for methods and limitations.

## Submission hygiene
Keep supporting questions, schema findings and verification register. Exclude private defence notes, learning journal, credentials, caches, raw data and generated reports. Preserve failure evidence. Final submission mechanics require confirmation. Review all pending acceptance items before final commit.
