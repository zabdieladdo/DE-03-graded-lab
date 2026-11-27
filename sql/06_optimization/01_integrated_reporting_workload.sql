-- E058: same six outputs as E050, one report per invocation.
\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_e058_report';
DO $$ BEGIN
 IF current_database() <> 'kloudkart_lab' THEN RAISE EXCEPTION 'Wrong database'; END IF;
END $$;
SELECT current_database(), current_setting('transaction_isolation'), current_setting('jit'), current_setting('work_mem');
SELECT clock_timestamp() AS started \gset
\echo --- customer_summary ---
\o /dev/null
COPY (SELECT * FROM public.customer_spending_summary(DATE '2026-08-31') ORDER BY customer_id) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- monthly_and_running ---
\o /dev/null
COPY (SELECT * FROM public.customer_monthly_running_spending(DATE '2026-08-31') ORDER BY customer_id, order_month) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- top100 ---
\o /dev/null
COPY (SELECT * FROM public.customer_top100(DATE '2026-08-31') ORDER BY ranking_position) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- ranking_metadata ---
\o /dev/null
COPY (SELECT * FROM public.customer_top100_metadata(DATE '2026-08-31')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- financial_reconciliation ---
\o /dev/null
COPY (SELECT * FROM public.spending_reconciliation(DATE '2026-08-31')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- period_metadata ---
\o /dev/null
COPY (SELECT * FROM public.monthly_reporting_metadata(DATE '2026-08-31')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
SELECT 1 AS workload_run, DATE '2026-08-31' AS as_of_date, ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - :'started'::timestamptz))*1000,3) AS workload_ms;

ROLLBACK;
