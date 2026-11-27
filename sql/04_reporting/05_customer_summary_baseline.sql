-- DE-03: Kloud Kart
-- Initial customer summary performance baseline

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect reporting database';
    END IF;
END;
$guard$;


\echo === 1. Execution environment ===

SELECT
    current_database() AS database_name,
    version() AS database_version;

SHOW work_mem;
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW max_parallel_workers_per_gather;
SHOW jit;


\echo === 2. Existing reporting indexes ===

SELECT
    tablename,
    indexname,
    indexdef

FROM pg_indexes

WHERE schemaname = 'public'

  AND tablename IN (
      'customers',
      'orders',
      'order_items'
  )

ORDER BY tablename, indexname;


\echo === 3. Customer summary execution plan ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT *

FROM public.customer_spending_summary(
    DATE '2026-08-31'
);


\echo === 4. Repeated execution ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT *

FROM public.customer_spending_summary(
    DATE '2026-08-31'
);


\echo === 5. Financial reconciliation execution plan ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT *

FROM public.spending_reconciliation(
    DATE '2026-08-31'
);


ROLLBACK;