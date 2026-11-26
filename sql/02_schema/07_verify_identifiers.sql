-- DE-03: Kloud Kart
-- Verify automatic identifier generation
-- without consuming sequence values.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Identity column definitions ===

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    is_identity,
    identity_generation,
    identity_start,
    identity_increment,
    identity_cycle
FROM information_schema.columns
WHERE table_schema = 'public'
    AND (
        (table_name = 'orders'
            AND column_name = 'order_id')
        OR
        (table_name = 'order_items'
            AND column_name = 'order_item_id')
        OR
        (table_name = 'inventory_log'
            AND column_name = 'log_id')
    )
ORDER BY table_name;

\echo === 3. Associated sequences ===

SELECT
    'orders' AS table_name,
    pg_get_serial_sequence(
        'public.orders', 'order_id'
    ) AS sequence_name

UNION ALL

SELECT
    'order_items',
    pg_get_serial_sequence(
        'public.order_items', 'order_item_id'
    )

UNION ALL

SELECT
    'inventory_log',
    pg_get_serial_sequence(
        'public.inventory_log', 'log_id'
    );

\echo === 4. Historical identifier preservation ===

SELECT
    'orders' AS table_name,
    COUNT(*) AS row_count,
    MIN(order_id) AS minimum_id,
    MAX(order_id) AS maximum_id
FROM orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    MIN(order_item_id),
    MAX(order_item_id)
FROM order_items

UNION ALL

SELECT
    'inventory_log',
    COUNT(*),
    MIN(log_id),
    MAX(log_id)
FROM inventory_log;

ROLLBACK;