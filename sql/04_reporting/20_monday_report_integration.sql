-- E050: Architecture A, current-volume same-snapshot Monday report.
-- No schema changes. Monthly running output also supplies monthly spending.
\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_monday_integration';
DO $$ BEGIN
 IF current_database() <> 'kloudkart_lab' THEN RAISE EXCEPTION 'Incorrect database'; END IF;
END $$;
\echo === Environment ===
SELECT version(), current_database(), current_setting('transaction_isolation') AS isolation,
 current_setting('transaction_read_only') AS read_only;
SELECT name, setting, unit FROM pg_settings WHERE name IN
 ('work_mem','shared_buffers','effective_cache_size','hash_mem_multiplier','block_size','jit','track_io_timing','max_parallel_workers_per_gather') ORDER BY name;
SELECT COUNT(*) AS source_orders FROM public.orders;
SELECT COUNT(*) AS source_customers FROM public.customers;
\echo === Same-snapshot correctness gate: both reporting dates ===
DO $$
DECLARE d date; bad bigint; s record; r record; t record; m record; w record;
BEGIN
 FOREACH d IN ARRAY ARRAY[DATE '2026-08-31', DATE '2026-11-26'] LOOP
  WITH summary AS MATERIALIZED (SELECT * FROM public.customer_spending_summary(d)),
  monthly AS MATERIALIZED (SELECT * FROM public.customer_monthly_running_spending(d)),
  per_customer AS (
   SELECT customer_id, COUNT(*) AS months, COUNT(DISTINCT order_month) AS distinct_months,
    SUM(monthly_spending) AS window_amount, SUM(monthly_order_count) AS window_n,
    MAX(opening_spending) AS opening_amount,
    (ARRAY_AGG(cumulative_since_extract_start ORDER BY order_month DESC))[1] AS final_history,
    (ARRAY_AGG(window_cumulative_spending ORDER BY order_month DESC))[1] AS final_window
   FROM monthly GROUP BY customer_id
  ), shared AS MATERIALIZED (SELECT * FROM public.customer_spending_totals(d))
  SELECT COUNT(*) INTO bad FROM summary a FULL JOIN per_customer b USING(customer_id)
   FULL JOIN shared c USING(customer_id)
  WHERE a.customer_id IS NULL OR b.customer_id IS NULL OR c.customer_id IS NULL
   OR b.months <> 12 OR b.distinct_months <> 12
   OR a.total_spent IS DISTINCT FROM c.recorded_history_spending
   OR a.order_count IS DISTINCT FROM c.recorded_history_order_count
   OR b.window_amount IS DISTINCT FROM c.window_spending
   OR b.window_n IS DISTINCT FROM c.window_order_count
   OR b.opening_amount IS DISTINCT FROM c.opening_spending
   OR b.final_history IS DISTINCT FROM a.total_spent
   OR b.final_window IS DISTINCT FROM b.window_amount
   OR b.opening_amount+b.window_amount IS DISTINCT FROM a.total_spent;
  IF bad <> 0 THEN RAISE EXCEPTION 'Cross-report differences %, date %',bad,d; END IF;
  RAISE NOTICE 'PASS I01: per-customer cross-report identities (%)',d;
  SELECT COUNT(*) AS n, COUNT(DISTINCT customer_id) AS distinct_n,
   COALESCE(SUM(total_spent),0) AS amount, COALESCE(SUM(order_count),0) AS orders
   INTO s FROM public.customer_spending_summary(d);
  SELECT * INTO STRICT r FROM public.spending_reconciliation(d);
  IF s.n <> (SELECT COUNT(*) FROM public.customers) OR s.n <> s.distinct_n
   OR s.amount IS DISTINCT FROM r.attributed_value OR s.orders IS DISTINCT FROM r.attributed_orders
   OR r.eligible_value IS DISTINCT FROM r.attributed_value+r.unattributed_value
   OR r.eligible_orders IS DISTINCT FROM r.attributed_orders+r.unattributed_orders THEN
   RAISE EXCEPTION 'History reconciliation failed (%)',d;
  END IF;
  RAISE NOTICE 'PASS I02: population and recorded-history reconciliation (%)',d;
  SELECT COUNT(*) AS n, COUNT(DISTINCT customer_id) AS distinct_n,
   COALESCE(SUM(ranking_spending),0) AS amount INTO t FROM public.customer_top100(d);
  SELECT * INTO STRICT m FROM public.customer_top100_metadata(d);
  SELECT COUNT(*) FILTER (WHERE window_spending > 0) AS n,
   COALESCE(SUM(window_spending) FILTER (WHERE window_spending > 0),0) AS amount
   INTO w FROM public.customer_spending_totals(d);
  IF t.n <> t.distinct_n OR t.n <> LEAST(100,w.n)
   OR t.n IS DISTINCT FROM m.selected_customer_count OR t.amount IS DISTINCT FROM m.selected_spending
   OR w.n IS DISTINCT FROM m.qualifying_customer_count OR w.amount IS DISTINCT FROM m.qualifying_spending THEN
   RAISE EXCEPTION 'Ranking metadata reconciliation failed (%)',d;
  END IF;
  RAISE NOTICE 'PASS I03: ranking population and metadata (%)',d;
  RAISE NOTICE 'INFO: date %, customers %, history orders %, history amount %, selected %, selected amount %',d,s.n,s.orders,s.amount,t.n,t.amount;
 END LOOP;
END $$;
\echo === Benchmark: CSV results transferred to local psql and discarded ===
\echo === Three headline runs and one November sensitivity run ===

\echo === WORKLOAD 1: 2026-08-31 ===
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

\echo === WORKLOAD 2: 2026-08-31 ===
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
SELECT 2 AS workload_run, DATE '2026-08-31' AS as_of_date, ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - :'started'::timestamptz))*1000,3) AS workload_ms;

\echo === WORKLOAD 3: 2026-08-31 ===
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
SELECT 3 AS workload_run, DATE '2026-08-31' AS as_of_date, ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - :'started'::timestamptz))*1000,3) AS workload_ms;

\echo === WORKLOAD 4: 2026-11-26 ===
SELECT clock_timestamp() AS started \gset
\echo --- customer_summary ---
\o /dev/null
COPY (SELECT * FROM public.customer_spending_summary(DATE '2026-11-26') ORDER BY customer_id) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- monthly_and_running ---
\o /dev/null
COPY (SELECT * FROM public.customer_monthly_running_spending(DATE '2026-11-26') ORDER BY customer_id, order_month) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- top100 ---
\o /dev/null
COPY (SELECT * FROM public.customer_top100(DATE '2026-11-26') ORDER BY ranking_position) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- ranking_metadata ---
\o /dev/null
COPY (SELECT * FROM public.customer_top100_metadata(DATE '2026-11-26')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- financial_reconciliation ---
\o /dev/null
COPY (SELECT * FROM public.spending_reconciliation(DATE '2026-11-26')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
\echo --- period_metadata ---
\o /dev/null
COPY (SELECT * FROM public.monthly_reporting_metadata(DATE '2026-11-26')) TO STDOUT WITH (FORMAT CSV, HEADER TRUE);
\o
SELECT 4 AS workload_run, DATE '2026-11-26' AS as_of_date, ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - :'started'::timestamptz))*1000,3) AS workload_ms;
ROLLBACK;
\echo === E050 completed ===
