-- DE-03 E048: equivalent ranking comparison and interface costs
\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_ranking_baseline';
DO $$ BEGIN
 IF current_database() <> 'kloudkart_lab' THEN RAISE EXCEPTION 'Incorrect database'; END IF;
END $$;
\echo === Environment ===
SELECT version();
SELECT name, setting, unit FROM pg_settings WHERE name IN
 ('work_mem','shared_buffers','effective_cache_size','hash_mem_multiplier','block_size','jit','track_io_timing','max_parallel_workers_per_gather') ORDER BY name;

-- The alternative returns the same 14 fields, using D029 sparse monthly
-- totals plus a separate opening aggregation. Store only SQL text in psql.
SELECT $query$
WITH params AS (
 SELECT DATE '2026-08-31' AS d, 'trailing_12_months'::text AS basis
), meta AS MATERIALIZED (
 SELECT m.*, p.basis FROM params p CROSS JOIN LATERAL public.monthly_reporting_metadata(p.d) m
), monthly AS (
 SELECT s.customer_id, SUM(s.monthly_spending) AS amount,
        SUM(s.monthly_order_count)::bigint AS n
 FROM params p CROSS JOIN LATERAL public.customer_monthly_spending_sparse(p.d) s
 GROUP BY s.customer_id
), opening AS (
 SELECT e.customer_id, SUM(e.total_amount) AS amount, COUNT(*) AS n
 FROM meta m CROSS JOIN LATERAL public.eligible_orders_as_of(m.as_of_date) e
 WHERE e.order_date < m.window_start GROUP BY e.customer_id
), totals AS (
 SELECT m.as_of_date, m.basis AS ranking_basis, m.window_start, m.is_partial_month,
 c.customer_id,c.full_name,
 COALESCE(w.amount,0::numeric) AS window_spending,
 COALESCE(w.n,0::bigint) AS window_order_count,
 COALESCE(w.amount,0::numeric)+COALESCE(o.amount,0::numeric) AS recorded_history_spending,
 COALESCE(w.n,0::bigint)+COALESCE(o.n,0::bigint) AS recorded_history_order_count
 FROM public.customers c CROSS JOIN meta m
 LEFT JOIN monthly w ON w.customer_id=c.customer_id
 LEFT JOIN opening o ON o.customer_id=c.customer_id
), candidates AS (
 SELECT t.*, CASE ranking_basis WHEN 'recorded_history' THEN recorded_history_spending ELSE window_spending END AS ranking_spending,
 CASE ranking_basis WHEN 'recorded_history' THEN recorded_history_order_count ELSE window_order_count END AS ranking_order_count
 FROM totals t
), ranked AS (
 SELECT c.*, ROW_NUMBER() OVER (ORDER BY ranking_spending DESC,customer_id) AS ranking_position,
 RANK() OVER (ORDER BY ranking_spending DESC) AS spending_rank
 FROM candidates c WHERE ranking_spending > 0
)
SELECT as_of_date,ranking_basis,window_start,is_partial_month,ranking_position,spending_rank,customer_id,full_name,ranking_spending,ranking_order_count,window_spending,window_order_count,recorded_history_spending,recorded_history_order_count
FROM ranked WHERE ranking_position <= 100 ORDER BY ranking_position
$query$ AS sparse_sql \gset

\echo === Equivalence gate: both dates and bases, all 14 fields ===
WITH scenarios(d,b) AS (VALUES (DATE '2026-08-31','trailing_12_months'),(DATE '2026-08-31','recorded_history'),(DATE '2026-11-26','trailing_12_months'),(DATE '2026-11-26','recorded_history'))
SELECT format($cmd$
WITH expected AS MATERIALIZED (%s), actual AS MATERIALIZED (
 SELECT * FROM public.customer_top100(%L::date,%L)
), differences AS (
 (SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
 UNION ALL
 (SELECT * FROM actual EXCEPT ALL SELECT * FROM expected)
)
SELECT %L AS scenario, COUNT(*) AS differences, 1 / CASE WHEN COUNT(*)=0 THEN 1 ELSE 0 END AS equality_gate FROM differences;
$cmd$,replace(replace(:'sparse_sql','2026-08-31',d::text),'''trailing_12_months''::text',quote_literal(b)||'::text'),d,b,d::text||' '||b)
FROM scenarios \gexec

\echo === Three alternating repetitions: same headline top-100 output ===
WITH runs(n,variant) AS (VALUES (1,'direct'),(2,'sparse'),(3,'sparse'),(4,'direct'),(5,'direct'),(6,'sparse'))
SELECT format('SELECT %L AS benchmark; EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS) %s;', n::text||' '||variant,
 CASE variant WHEN 'direct' THEN 'SELECT * FROM public.customer_top100(DATE ''2026-08-31'') ORDER BY ranking_position' ELSE :'sparse_sql' END)
FROM runs ORDER BY n \gexec

\echo === Shared totals, full ranks, metadata, and filtered totals ===
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_spending_totals(DATE '2026-08-31');
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_spending_ranked(DATE '2026-08-31');
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_top100_metadata(DATE '2026-08-31');
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_spending_totals(DATE '2026-08-31') WHERE customer_id=100001;
\echo === Sensitivity: November window and headline history ===
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_top100(DATE '2026-11-26') ORDER BY ranking_position;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM public.customer_top100(DATE '2026-08-31','recorded_history') ORDER BY ranking_position;
ROLLBACK;
\echo === E048 completed ===
