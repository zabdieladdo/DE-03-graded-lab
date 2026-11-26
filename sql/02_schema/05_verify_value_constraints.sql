-- DE-03: Kloud Kart
-- Verify value constraints and historical preservation.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Check constraint definitions ===

SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    convalidated AS validated,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'c'
    AND connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text, conname;

\echo === 3. Constraint summary ===

SELECT
    COUNT(*) AS total_check_constraints,
    COUNT(*) FILTER (
        WHERE convalidated
    ) AS validated_constraints,
    COUNT(*) FILTER (
        WHERE NOT convalidated
    ) AS unvalidated_constraints
FROM pg_constraint
WHERE contype = 'c'
    AND connamespace = 'public'::regnamespace;

\echo === 4. Historical value exceptions ===

SELECT
    'Invalid order item quantities' AS finding,
    COUNT(*) AS affected_rows
FROM order_items
WHERE quantity IS NULL OR quantity <= 0

UNION ALL

SELECT
    'Invalid product stock',
    COUNT(*)
FROM products
WHERE stock_quantity IS NULL OR stock_quantity < 0

UNION ALL

SELECT
    'Invalid product prices',
    COUNT(*)
FROM products
WHERE price IS NULL OR price < 0

UNION ALL

SELECT
    'Invalid order item prices',
    COUNT(*)
FROM order_items
WHERE unit_price IS NULL OR unit_price < 0

UNION ALL

SELECT
    'Invalid order totals',
    COUNT(*)
FROM orders
WHERE total_amount IS NULL OR total_amount < 0;

\echo === 5. Legitimate zero values preserved ===

SELECT
    'Zero product stock' AS finding,
    COUNT(*) AS affected_rows
FROM products
WHERE stock_quantity = 0

UNION ALL

SELECT
    'Zero order item prices',
    COUNT(*)
FROM order_items
WHERE unit_price = 0

UNION ALL

SELECT
    'Zero inventory movements',
    COUNT(*)
FROM inventory_log
WHERE change_qty = 0;

ROLLBACK;