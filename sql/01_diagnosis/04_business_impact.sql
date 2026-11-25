-- DE-03: Financial and operational impact investigation
-- Quantify exposure without claiming unverified financial losses.

\set ON_ERROR_STOP on
\pset pager off
\pset format aligned

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo '=== 1. Database identity ==='

SELECT current_database() AS database_name;

\echo '=== 2. Orphaned order item exposure ==='

SELECT
    COUNT(*) AS affected_items,
    COUNT(DISTINCT oi.order_id) AS missing_order_ids,
    SUM(oi.quantity) AS recorded_units,
    COUNT(*) FILTER (
        WHERE oi.quantity IS NULL
            OR oi.unit_price IS NULL
    ) AS incomplete_line_values,
    SUM(oi.quantity * oi.unit_price) AS known_line_value
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE oi.order_id IS NOT NULL
    AND o.order_id IS NULL;

\echo '=== 3. Orders without valid customers ==='

WITH orphaned_orders AS (
    SELECT
        o.customer_id,
        o.total_amount,
        CASE LOWER(TRIM(o.status))
            WHEN 'complete' THEN 'completed'
            WHEN 'canceled' THEN 'cancelled'
            ELSE LOWER(TRIM(o.status))
        END AS candidate_status
    FROM orders AS o
    LEFT JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.customer_id IS NOT NULL
        AND c.customer_id IS NULL
)
SELECT
    candidate_status,
    COUNT(*) AS affected_orders,
    COUNT(DISTINCT customer_id) AS missing_customer_ids,
    SUM(total_amount) AS recorded_order_amount
FROM orphaned_orders
GROUP BY candidate_status
ORDER BY affected_orders DESC;

\echo '=== 4. Missing and zero item prices ==='

SELECT
    CASE
        WHEN unit_price IS NULL THEN 'Missing price'
        WHEN unit_price = 0 THEN 'Zero price'
    END AS price_condition,
    COUNT(*) AS affected_items,
    COUNT(DISTINCT order_id) AS affected_order_ids,
    SUM(quantity) AS affected_units
FROM order_items
WHERE unit_price IS NULL
    OR unit_price = 0
GROUP BY 1
ORDER BY price_condition;

\echo '=== 5. Negative stock exposure ==='

SELECT
    COUNT(*) AS affected_products,
    SUM(ABS(stock_quantity)) AS stock_deficit_units,
    SUM(
        ABS(stock_quantity) * price
    ) AS indicative_catalogue_value
FROM products
WHERE stock_quantity < 0;

\echo '=== 6. Negative stock details ==='

SELECT
    product_id,
    product_name,
    stock_quantity,
    price,
    ABS(stock_quantity) * price AS indicative_value
FROM products
WHERE stock_quantity < 0
ORDER BY indicative_value DESC, product_id;

\echo '=== 7. Order and item value reconciliation ==='

WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(*) FILTER (
            WHERE quantity IS NULL
                OR unit_price IS NULL
        ) AS incomplete_items,
        SUM(quantity * unit_price) AS item_total
    FROM order_items
    GROUP BY order_id
),
classified AS (
    SELECT
        o.order_id,
        o.total_amount,
        it.item_total,
        CASE
            WHEN it.order_id IS NULL
                THEN 'No matching items'
            WHEN it.incomplete_items > 0
                THEN 'Incomplete item values'
            WHEN o.total_amount IS NULL
                THEN 'Missing order total'
            WHEN o.total_amount = it.item_total
                THEN 'Exact match'
            WHEN o.total_amount > it.item_total
                THEN 'Order total above item total'
            ELSE 'Order total below item total'
        END AS reconciliation_status
    FROM orders AS o
    LEFT JOIN item_totals AS it
        ON o.order_id = it.order_id
)
SELECT
    reconciliation_status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS recorded_order_amount,
    SUM(item_total) AS known_item_amount,
    SUM(
        ABS(total_amount - item_total)
    ) FILTER (
        WHERE reconciliation_status IN (
            'Exact match',
            'Order total above item total',
            'Order total below item total'
        )
    ) AS absolute_difference
FROM classified
GROUP BY reconciliation_status
ORDER BY order_count DESC;

\echo '=== 8. Orphaned inventory movement exposure ==='

SELECT
    il.reason,
    COUNT(*) AS affected_movements,
    COUNT(DISTINCT il.product_id) AS missing_product_ids,
    SUM(il.change_qty) AS net_quantity,
    SUM(ABS(il.change_qty)) AS gross_movement_units
FROM inventory_log AS il
LEFT JOIN products AS p
    ON il.product_id = p.product_id
WHERE il.product_id IS NOT NULL
    AND p.product_id IS NULL
GROUP BY il.reason
ORDER BY affected_movements DESC;

\echo '=== 9. Largest order item quantities ==='

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS line_value,
    o.status,
    o.total_amount AS recorded_order_total
FROM order_items AS oi
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
ORDER BY oi.quantity DESC NULLS LAST,
    oi.order_item_id
LIMIT 20;

ROLLBACK;