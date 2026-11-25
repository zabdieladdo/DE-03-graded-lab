-- DE-03: Raw status investigation
-- Examine original status values without normalization.

\set ON_ERROR_STOP on
\pset pager off
\pset format aligned

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo '=== 1. Database identity ==='

SELECT current_database() AS database_name;

\echo '=== 2. Original order status distribution ==='

SELECT
    QUOTE_NULLABLE(status) AS raw_status,
    LENGTH(status) AS character_count,
    COUNT(*) AS order_count,
    SUM(total_amount) AS recorded_amount
FROM orders
GROUP BY status
ORDER BY order_count DESC;

\echo '=== 3. Missing and zero prices by original status ==='

SELECT
    QUOTE_NULLABLE(o.status) AS raw_status,
    COUNT(*) FILTER (
        WHERE oi.unit_price IS NULL
    ) AS missing_price_items,
    COUNT(*) FILTER (
        WHERE oi.unit_price = 0
    ) AS zero_price_items,
    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE oi.unit_price IS NULL
    ) AS missing_price_orders,
    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE oi.unit_price = 0
    ) AS zero_price_orders,
    SUM(oi.quantity) FILTER (
        WHERE oi.unit_price IS NULL
    ) AS missing_price_units,
    SUM(oi.quantity) FILTER (
        WHERE oi.unit_price = 0
    ) AS zero_price_units
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE oi.unit_price IS NULL
    OR oi.unit_price = 0
GROUP BY o.status
ORDER BY o.status;

\echo '=== 4. Orders without valid customers by original status ==='

SELECT
    QUOTE_NULLABLE(o.status) AS raw_status,
    COUNT(*) AS affected_orders,
    COUNT(DISTINCT o.customer_id) AS missing_customer_ids,
    SUM(o.total_amount) AS recorded_order_amount
FROM orders AS o
LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL
    AND c.customer_id IS NULL
GROUP BY o.status
ORDER BY affected_orders DESC;

\echo '=== 5. Missing and zero price reconciliation ==='

SELECT
    COUNT(*) FILTER (
        WHERE unit_price IS NULL
    ) AS missing_price_items,
    COUNT(*) FILTER (
        WHERE unit_price = 0
    ) AS zero_price_items,
    SUM(quantity) FILTER (
        WHERE unit_price IS NULL
    ) AS missing_price_units,
    SUM(quantity) FILTER (
        WHERE unit_price = 0
    ) AS zero_price_units
FROM order_items;

ROLLBACK;