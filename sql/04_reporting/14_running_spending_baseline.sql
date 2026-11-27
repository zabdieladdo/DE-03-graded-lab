
-- DE-03: Kloud Kart
-- Stage 04.5: Running spending performance baseline
-- Decision: D030
-- Evidence: E044
--
-- No indexes or configuration changes.
-- Read-only repeated performance measurements.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';

SET LOCAL application_name =
    'de03_running_baseline';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


-- =====================================================
-- 1. Environment
-- =====================================================

\echo === 1. Performance environment ===

SELECT
    CURRENT_DATABASE() AS database_name,
    VERSION() AS postgres_version,
    CURRENT_TIMESTAMP AS measured_at;

SELECT
    name,
    setting,
    unit
FROM pg_settings
WHERE name IN (
    'work_mem',
    'shared_buffers',
    'effective_cache_size',
    'hash_mem_multiplier',
    'max_parallel_workers_per_gather',
    'block_size',
    'jit',
    'track_io_timing'
)
ORDER BY name;


-- =====================================================
-- 2. Headline measurements: round 1
-- =====================================================

\echo === 2A. Dense monthly reference - run 1 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_spending(
    DATE '2026-08-31'
);


\echo === 2B. Monthly running spending - run 1 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-08-31'
);


\echo === 2C. Transaction running spending - run 1 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-08-31'
);


-- =====================================================
-- 3. Headline measurements: round 2
-- =====================================================

\echo === 3A. Dense monthly reference - run 2 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_spending(
    DATE '2026-08-31'
);


\echo === 3B. Monthly running spending - run 2 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-08-31'
);


\echo === 3C. Transaction running spending - run 2 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-08-31'
);


-- =====================================================
-- 4. Headline measurements: round 3
-- =====================================================

\echo === 4A. Dense monthly reference - run 3 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_spending(
    DATE '2026-08-31'
);


\echo === 4B. Monthly running spending - run 3 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-08-31'
);


\echo === 4C. Transaction running spending - run 3 ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-08-31'
);


-- =====================================================
-- 5. Sensitivity date
-- =====================================================

\echo === 5A. Monthly running spending - sensitivity ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-11-26'
);


\echo === 5B. Transaction running spending - sensitivity ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-11-26'
);


-- =====================================================
-- 6. Single-customer filtering
-- =====================================================

\echo === 6A. Monthly running - single customer ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-08-31'
)
WHERE customer_id = 100001;


\echo === 6B. Transaction running - single customer ===

EXPLAIN (
    ANALYZE, BUFFERS, VERBOSE, SETTINGS
)
SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-08-31'
)
WHERE customer_id = 100001;


ROLLBACK;

\echo === Running spending baseline completed ===
