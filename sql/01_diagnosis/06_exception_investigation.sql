-- DE-03: Stage 01.6
-- Distinguish suspicious records from confirmed defects.

\set ON_ERROR_STOP on
\pset pager off
\pset format aligned

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo '=== 1. Database identity ==='

SELECT current_database() AS database_name;

\echo '=== 2. Order item quantity distribution ==='

SELECT
    quantity,
    COUNT(*) AS item_count,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    SUM(quantity * unit_price) AS known_line_value
FROM order_items
GROUP BY quantity
ORDER BY quantity;

\echo '=== 3. Unusually large quantities in order context ==='

WITH order_context AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(quantity * unit_price) AS known_item_total,
        COUNT(*) FILTER (
            WHERE unit_price IS NULL
        ) AS missing_prices
    FROM order_items
    GROUP BY order_id
)
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS line_value,
    oc.item_count,
    oc.known_item_total,
    oc.missing_prices,
    o.total_amount AS checkout_total,
    o.status
FROM order_items AS oi
JOIN order_context AS oc
    ON oi.order_id = oc.order_id
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE oi.quantity > 10
ORDER BY oi.quantity DESC, oi.order_item_id;

\echo '=== 4. Missing and zero prices in business context ==='

SELECT
    CASE
        WHEN oi.unit_price IS NULL THEN 'Missing price'
        ELSE 'Zero price'
    END AS price_condition,
    CASE LOWER(TRIM(o.status))
        WHEN 'complete' THEN 'completed'
        WHEN 'canceled' THEN 'cancelled'
        ELSE LOWER(TRIM(o.status))
    END AS candidate_status,
    COUNT(*) AS affected_items,
    COUNT(DISTINCT oi.order_id) AS affected_order_ids,
    SUM(oi.quantity) AS affected_units
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE oi.unit_price IS NULL
    OR oi.unit_price = 0
GROUP BY 1, 2
ORDER BY 1, 2;

\echo '=== 5. Order total discrepancy distribution ==='

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS item_total,
        COUNT(*) FILTER (
            WHERE quantity IS NULL
                OR unit_price IS NULL
        ) AS incomplete_items
    FROM order_items
    GROUP BY order_id
),
differences AS (
    SELECT
        o.order_id,
        o.total_amount - it.item_total AS difference
    FROM orders AS o
    JOIN item_totals AS it
        ON o.order_id = it.order_id
    WHERE it.incomplete_items = 0
        AND o.total_amount IS NOT NULL
        AND o.total_amount <> it.item_total
),
classified AS (
    SELECT
        order_id,
        difference,
        CASE
            WHEN ABS(difference) <= 0.01 THEN '01: Up to 0.01'
            WHEN ABS(difference) <= 1 THEN '02: Up to 1'
            WHEN ABS(difference) <= 10 THEN '03: Up to 10'
            WHEN ABS(difference) <= 100 THEN '04: Up to 100'
            WHEN ABS(difference) <= 1000 THEN '05: Up to 1000'
            ELSE '06: Above 1000'
        END AS difference_band
    FROM differences
)
SELECT
    difference_band,
    COUNT(*) AS affected_orders,
    SUM(ABS(difference)) AS absolute_difference,
    SUM(difference) AS net_difference
FROM classified
GROUP BY difference_band
ORDER BY difference_band;

\echo '=== 6. Duplicate email identity characteristics ==='

WITH email_groups AS (
    SELECT
        LOWER(TRIM(email)) AS normalized_email,
        COUNT(*) AS customer_count,
        COUNT(DISTINCT LOWER(TRIM(full_name))) AS distinct_names,
        COUNT(DISTINCT TRIM(phone)) AS distinct_phones,
        COUNT(DISTINCT LOWER(TRIM(city))) AS distinct_cities
    FROM customers
    WHERE NULLIF(TRIM(email), '') IS NOT NULL
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_email_groups,
    COUNT(*) FILTER (
        WHERE distinct_names = 1
    ) AS same_name_groups,
    COUNT(*) FILTER (
        WHERE distinct_names > 1
    ) AS different_name_groups,
    COUNT(*) FILTER (
        WHERE distinct_phones = 1
    ) AS same_phone_groups,
    COUNT(*) FILTER (
        WHERE distinct_phones > 1
    ) AS different_phone_groups,
    COUNT(*) FILTER (
        WHERE distinct_cities > 1
    ) AS different_city_groups
FROM email_groups;

\echo '=== 7. Category hierarchy investigation ==='

WITH RECURSIVE ancestry AS (
    SELECT
        category_id AS starting_category_id,
        category_id AS current_category_id,
        parent_id,
        ARRAY[category_id] AS visited_path,
        FALSE AS cycle_detected
    FROM categories

    UNION ALL

    SELECT
        a.starting_category_id,
        p.category_id,
        p.parent_id,
        a.visited_path || p.category_id,
        p.category_id = ANY(a.visited_path)
    FROM ancestry AS a
    JOIN categories AS p
        ON a.parent_id = p.category_id
    WHERE NOT a.cycle_detected
),
classified AS (
    SELECT
        starting_category_id,
        CASE
            WHEN cycle_detected THEN 'Cycle detected'
            WHEN parent_id IS NULL THEN 'Root reachable'
            WHEN NOT EXISTS (
                SELECT 1
                FROM categories AS c
                WHERE c.category_id = ancestry.parent_id
            ) THEN 'Missing ancestor'
        END AS hierarchy_status,
        visited_path
    FROM ancestry
    WHERE cycle_detected
        OR parent_id IS NULL
        OR NOT EXISTS (
            SELECT 1
            FROM categories AS c
            WHERE c.category_id = ancestry.parent_id
        )
)
SELECT
    hierarchy_status,
    COUNT(*) AS affected_categories
FROM classified
GROUP BY hierarchy_status
ORDER BY hierarchy_status;

\echo '=== 8. Products without assigned categories ==='

SELECT
    COUNT(*) AS uncategorised_products,
    SUM(stock_quantity) AS recorded_stock,
    COUNT(*) FILTER (
        WHERE stock_quantity < 10
    ) AS candidate_low_stock_products,
    COUNT(*) FILTER (
        WHERE stock_quantity < 0
    ) AS negative_stock_products
FROM products
WHERE category_id IS NULL;

\echo '=== 9. Inventory history coverage ==='

WITH movements AS (
    SELECT
        product_id,
        COUNT(*) AS movement_count,
        SUM(change_qty) AS net_movement
    FROM inventory_log
    GROUP BY product_id
)
SELECT
    COUNT(*) AS total_products,
    COUNT(*) FILTER (
        WHERE m.product_id IS NULL
    ) AS products_without_history,
    COUNT(*) FILTER (
        WHERE m.product_id IS NOT NULL
    ) AS products_with_history,
    COUNT(*) FILTER (
        WHERE p.stock_quantity = m.net_movement
    ) AS stock_equals_net_movement,
    COUNT(*) FILTER (
        WHERE p.stock_quantity <> m.net_movement
    ) AS stock_differs_from_net_movement
FROM products AS p
LEFT JOIN movements AS m
    ON p.product_id = m.product_id;

\echo '=== 10. Negative stock and recorded movement history ==='

WITH movements AS (
    SELECT
        product_id,
        COUNT(*) AS movement_count,
        SUM(change_qty) AS net_movement,
        MIN(created_at) AS earliest_movement,
        MAX(created_at) AS latest_movement
    FROM inventory_log
    GROUP BY product_id
)
SELECT
    p.product_id,
    p.stock_quantity,
    m.movement_count,
    m.net_movement,
    p.stock_quantity - m.net_movement
        AS implied_opening_or_unrecorded_stock,
    m.earliest_movement,
    m.latest_movement
FROM products AS p
LEFT JOIN movements AS m
    ON p.product_id = m.product_id
WHERE p.stock_quantity < 0
ORDER BY p.product_id;

ROLLBACK;