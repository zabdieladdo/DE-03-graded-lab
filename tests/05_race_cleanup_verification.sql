\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT current_database() AS database_name;

\echo === 1. Baseline reconciliation ===

WITH expected(table_name, expected_rows) AS (
    VALUES
        ('categories', 94),
        ('products', 4023),
        ('customers', 40420),
        ('orders', 159384),
        ('order_items', 336559),
        ('inventory_log', 282352)
),
actual AS (
    SELECT 'categories' AS table_name, COUNT(*) AS actual_rows
    FROM categories

    UNION ALL
    SELECT 'products', COUNT(*) FROM products

    UNION ALL
    SELECT 'customers', COUNT(*) FROM customers

    UNION ALL
    SELECT 'orders', COUNT(*) FROM orders

    UNION ALL
    SELECT 'order_items', COUNT(*) FROM order_items

    UNION ALL
    SELECT 'inventory_log', COUNT(*) FROM inventory_log
)
SELECT
    e.table_name,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows AS difference,
    CASE
        WHEN a.actual_rows = e.expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM expected e
JOIN actual a USING (table_name)
ORDER BY e.table_name;

\echo === 2. Automated cleanup assertions ===

DO $test$
DECLARE
    v_fixture_ids integer[];
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;

    SELECT ARRAY(
        SELECT generate_series(10023, 10047)
        UNION ALL SELECT 10123
        UNION ALL SELECT 10223
        UNION ALL SELECT 10323
    )
    INTO v_fixture_ids;

    IF EXISTS (
        SELECT 1
        FROM products
        WHERE product_name LIKE 'RACE TEST FIXTURE%'
           OR product_id = ANY(v_fixture_ids)
    ) THEN
        RAISE EXCEPTION 'Race fixture products remain';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM order_items
        WHERE product_id = ANY(v_fixture_ids)
    ) THEN
        RAISE EXCEPTION 'Race fixture order items remain';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM inventory_log
        WHERE product_id = ANY(v_fixture_ids)
    ) THEN
        RAISE EXCEPTION 'Race fixture inventory logs remain';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM orders
        WHERE order_id BETWEEN 659390 AND 659469
    ) THEN
        RAISE EXCEPTION 'Race fixture orders remain';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM order_items
        WHERE order_id BETWEEN 659390 AND 659469
    ) THEN
        RAISE EXCEPTION 'Race fixture order references remain';
    END IF;

    IF (SELECT COUNT(*) FROM categories) <> 94
       OR (SELECT COUNT(*) FROM products) <> 4023
       OR (SELECT COUNT(*) FROM customers) <> 40420
       OR (SELECT COUNT(*) FROM orders) <> 159384
       OR (SELECT COUNT(*) FROM order_items) <> 336559
       OR (SELECT COUNT(*) FROM inventory_log) <> 282352
    THEN
        RAISE EXCEPTION 'Baseline row counts changed';
    END IF;

    RAISE NOTICE 'PASS: All race fixture products removed';
    RAISE NOTICE 'PASS: All race fixture order items removed';
    RAISE NOTICE 'PASS: All race fixture inventory logs removed';
    RAISE NOTICE 'PASS: All 80 generated race orders removed';
    RAISE NOTICE 'PASS: All six baseline counts reconciled';
    RAISE NOTICE 'RESULT: Race cleanup verification passed';
END;
$test$;

\echo === 3. Remaining historical negative stock ===

SELECT COUNT(*) AS negative_stock_products
FROM products
WHERE stock_quantity < 0;

\echo === 4. Identifier sequence state ===

SELECT last_value, is_called
FROM orders_order_id_seq;

ROLLBACK;