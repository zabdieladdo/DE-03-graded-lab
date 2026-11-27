# Stage 04 — Customer spending reports

## Status

Implemented and functionally verified. Candidate functional acceptance passed; the five-second concurrent target was missed in six acceptance trials. Final merged revision verification pending. See ADR-003, ADR-004 and `deliverables/performance/customer_reporting_performance.md` from repository root.

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

Headline reference: 40,420 customers; 111,190 attributed eligible history orders, 339,176,836.88; 144 unattributed eligible orders, 388,780.89; 485,040 monthly rows; window spending 334,634,759.00; top-100 window spending 14,781,340.27. Amounts are recorded monetary units; currency unconfirmed. These are baseline-specific, not hardcoded business rules.

## Performance and remaining verification

Four original integrated runs exceeded the provisional five-second SQL target. A later solo run (3.487 s) and concurrent run (4.227 s) met it. These are not controlled before/after comparisons or a guarantee. Candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending. See the integrated workload performance report.
