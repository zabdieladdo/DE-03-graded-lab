-- DE-03: Kloud Kart
-- Stage 04.1: Reporting requirements and data profiling

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SELECT current_database() AS database_name;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect reporting database';
    END IF;
END;
$guard$;

\echo === 1. Reporting date coverage ===

SELECT
    CURRENT_DATE AS execution_date,
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_date IS NULL
    ) AS missing_order_dates,
    COUNT(*) FILTER (
        WHERE order_date >= CURRENT_DATE + 1
    ) AS future_dated_orders
FROM orders;


\echo === 2. Eligible order date coverage ===

SELECT
    MIN(order_date) AS earliest_eligible_order,
    MAX(order_date) AS latest_eligible_order,
    COUNT(*) AS eligible_orders,
    COUNT(*) FILTER (
        WHERE order_date IS NULL
    ) AS missing_order_dates,
    SUM(total_amount) AS recorded_order_value
FROM orders
WHERE LOWER(BTRIM(status)) IN (
    'completed',
    'complete'
);


\echo === 3. Monthly order distribution ===

SELECT
    DATE_TRUNC('month', order_date)::date AS order_month,

    COUNT(*) AS all_orders,

    COUNT(*) FILTER (
        WHERE LOWER(BTRIM(status)) IN (
            'completed',
            'complete'
        )
    ) AS eligible_orders,

    SUM(total_amount) FILTER (
        WHERE LOWER(BTRIM(status)) IN (
            'completed',
            'complete'
        )
    ) AS eligible_order_value

FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY order_month;


\echo === 4. Customer spending reconciliation ===

WITH eligible_orders AS (

    SELECT
        order_id,
        customer_id,
        total_amount

    FROM orders

    WHERE LOWER(BTRIM(status)) IN (
        'completed',
        'complete'
    )

)

SELECT

    COUNT(*) AS eligible_orders,

    SUM(e.total_amount) AS eligible_order_value,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NOT NULL
    ) AS attributed_orders,

    SUM(e.total_amount) FILTER (
        WHERE c.customer_id IS NOT NULL
    ) AS attributed_order_value,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NULL
    ) AS unattributed_orders,

    SUM(e.total_amount) FILTER (
        WHERE c.customer_id IS NULL
    ) AS unattributed_order_value,

    COUNT(DISTINCT c.customer_id)
        AS customers_with_eligible_orders

FROM eligible_orders e

LEFT JOIN customers c
    ON c.customer_id = e.customer_id;


\echo === 5. Customer reporting coverage ===

WITH eligible_customers AS (

    SELECT DISTINCT customer_id

    FROM orders

    WHERE LOWER(BTRIM(status)) IN (
        'completed',
        'complete'
    )

)

SELECT

    COUNT(*) AS total_customers,

    COUNT(e.customer_id)
        AS customers_with_eligible_orders,

    COUNT(*) FILTER (
        WHERE e.customer_id IS NULL
    ) AS customers_without_eligible_orders

FROM customers c

LEFT JOIN eligible_customers e
    ON e.customer_id = c.customer_id;


\echo === 6. Current reporting-related indexes ===

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


\echo === 7. Current reporting table sizes ===

SELECT
    relname AS table_name,

    pg_size_pretty(
        pg_relation_size(relid)
    ) AS table_size,

    pg_size_pretty(
        pg_indexes_size(relid)
    ) AS index_size,

    pg_size_pretty(
        pg_total_relation_size(relid)
    ) AS total_size

FROM pg_stat_user_tables

WHERE schemaname = 'public'
  AND relname IN (
      'customers',
      'orders',
      'order_items'
  )

ORDER BY relname;

ROLLBACK;