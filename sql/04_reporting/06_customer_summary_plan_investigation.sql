-- DE-03: Kloud Kart
-- Investigation of reporting query execution strategies
-- No schema, data or persistent configuration changes.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '60s';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. PostgreSQL block size ===

SHOW block_size;


\echo === 2. Customer summary underlying query ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

WITH spending AS (

    SELECT
        e.customer_id,
        SUM(e.total_amount) AS total_spent,
        COUNT(*) AS order_count,
        MIN(e.order_date) AS first_order_date,
        MAX(e.order_date) AS last_order_date

    FROM public.eligible_orders_as_of(
        DATE '2026-08-31'
    ) e

    GROUP BY e.customer_id

)

SELECT
    DATE '2026-08-31' AS as_of_date,
    c.customer_id,
    c.full_name,
    COALESCE(s.total_spent, 0),
    COALESCE(s.order_count, 0),
    s.first_order_date,
    s.last_order_date

FROM public.customers c

LEFT JOIN spending s
    ON s.customer_id = c.customer_id;


\echo === 3. Financial reconciliation underlying query ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT
    DATE '2026-08-31' AS as_of_date,
    COUNT(*) AS eligible_orders,
    COALESCE(SUM(e.total_amount), 0)
        AS eligible_value,

    COUNT(c.customer_id) AS attributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE c.customer_id IS NOT NULL
        ), 0
    ) AS attributed_value,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NULL
    ) AS unattributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE c.customer_id IS NULL
        ), 0
    ) AS unattributed_value

FROM public.eligible_orders_as_of(
    DATE '2026-08-31'
) e

LEFT JOIN public.customers c
    ON c.customer_id = e.customer_id;


\echo === 4. Eligibility function execution plan ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT *

FROM public.eligible_orders_as_of(
    DATE '2026-08-31'
);


\echo === 5. Direct eligibility view execution plan ===

EXPLAIN (
    ANALYZE,
    BUFFERS,
    VERBOSE,
    SETTINGS
)

SELECT *

FROM public.v_eligible_orders

WHERE order_date <
    DATE '2026-08-31' + INTERVAL '1 day';


ROLLBACK;