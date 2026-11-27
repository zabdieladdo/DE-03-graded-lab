-- DE-03: Kloud Kart
-- Preliminary monthly reporting performance baseline

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. Execution environment ===

SELECT version();

SHOW work_mem;
SHOW shared_buffers;
SHOW hash_mem_multiplier;
SHOW max_parallel_workers_per_gather;
SHOW block_size;


\echo === 2. Sparse report execution ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending_sparse(
    DATE '2026-08-31'
);


\echo === 3. Dense report execution ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending(
    DATE '2026-08-31'
);


\echo === 4. Dense report repeated execution ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending(
    DATE '2026-08-31'
);


\echo === 5. Wide-format export execution ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending_wide(
    DATE '2026-08-31'
);


\echo === 6. Sensitivity-date dense execution ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending(
    DATE '2026-11-26'
);


\echo === 7. Single-customer consumption ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)

SELECT *

FROM public.customer_monthly_spending(
    DATE '2026-08-31'
)

WHERE customer_id = (
    SELECT MIN(customer_id)
    FROM public.customers
);


ROLLBACK;