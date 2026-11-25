-- DE-03: Stage 01.4 — Business value validation
-- Profile values before deciding which business rules to enforce.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo '=== 1. Database identity ==='

SELECT current_database() AS database_name;

\echo '=== 2. Raw order status distribution ==='

SELECT
    QUOTE_NULLABLE(status) AS raw_status,
    LENGTH(status) AS character_count,
    COUNT(*) AS order_count,
    COUNT(*) FILTER (
        WHERE total_amount IS NULL
    ) AS missing_amounts,
    SUM(total_amount) AS recorded_amount
FROM orders
GROUP BY status
ORDER BY order_count DESC, raw_status;

\echo '=== 3. Candidate status normalization ==='

WITH normalized AS (
    SELECT
        CASE LOWER(TRIM(status))
            WHEN 'complete' THEN 'completed'
            WHEN 'canceled' THEN 'cancelled'
            ELSE LOWER(TRIM(status))
        END AS candidate_status,
        total_amount
    FROM orders
)
SELECT
    candidate_status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS recorded_amount
FROM normalized
GROUP BY candidate_status
ORDER BY order_count DESC;

\echo '=== 4. Numeric value profiling ==='

WITH value_profiles AS (
    SELECT
        'products.stock_quantity' AS field,
        stock_quantity::numeric AS value
    FROM products

    UNION ALL

    SELECT
        'products.price',
        price
    FROM products

    UNION ALL

    SELECT
        'orders.total_amount',
        total_amount
    FROM orders

    UNION ALL

    SELECT
        'order_items.quantity',
        quantity::numeric
    FROM order_items

    UNION ALL

    SELECT
        'order_items.unit_price',
        unit_price
    FROM order_items

    UNION ALL

    SELECT
        'inventory_log.change_qty',
        change_qty::numeric
    FROM inventory_log
)
SELECT
    field,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE value IS NULL
    ) AS missing_values,
    COUNT(*) FILTER (
        WHERE value < 0
    ) AS negative_values,
    COUNT(*) FILTER (
        WHERE value = 0
    ) AS zero_values,
    COUNT(*) FILTER (
        WHERE value > 0
    ) AS positive_values,
    MIN(value) AS minimum_value,
    MAX(value) AS maximum_value
FROM value_profiles
GROUP BY field
ORDER BY field;

\echo '=== 5. Potential duplicate customer emails ==='

WITH duplicate_groups AS (
    SELECT
        LOWER(TRIM(email)) AS normalized_email,
        COUNT(*) AS customer_count
    FROM customers
    WHERE NULLIF(TRIM(email), '') IS NOT NULL
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_email_groups,
    COALESCE(SUM(customer_count), 0) AS affected_customer_rows,
    COALESCE(SUM(customer_count - 1), 0) AS excess_rows_if_unique,
    MAX(customer_count) AS largest_group
FROM duplicate_groups;

\echo '=== 6. Missing customer information ==='

SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(full_name), '') IS NULL
    ) AS missing_names,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(email), '') IS NULL
    ) AS missing_emails,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(phone), '') IS NULL
    ) AS missing_phones,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(city), '') IS NULL
    ) AS missing_cities,
    COUNT(*) FILTER (
        WHERE registered_at IS NULL
    ) AS missing_registration_dates
FROM customers;

\echo '=== 7. Inventory movement reason and direction ==='

SELECT
    QUOTE_NULLABLE(reason) AS movement_reason,
    COUNT(*) AS total_movements,
    COUNT(*) FILTER (
        WHERE change_qty < 0
    ) AS negative_movements,
    COUNT(*) FILTER (
        WHERE change_qty > 0
    ) AS positive_movements,
    COUNT(*) FILTER (
        WHERE change_qty = 0
    ) AS zero_movements,
    COUNT(*) FILTER (
        WHERE change_qty IS NULL
    ) AS unknown_movements,
    SUM(change_qty) AS net_quantity_change
FROM inventory_log
GROUP BY reason
ORDER BY total_movements DESC;

ROLLBACK;