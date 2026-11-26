-- DE-03: Kloud Kart
-- Inspect existing identifiers before automatic generation.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Existing identifier ranges ===

SELECT
    'orders' AS table_name,
    COUNT(*) AS row_count,
    MIN(order_id) AS minimum_id,
    MAX(order_id) AS maximum_id,
    MAX(order_id)::bigint + 1 AS next_candidate_id
FROM orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    MIN(order_item_id),
    MAX(order_item_id),
    MAX(order_item_id)::bigint + 1
FROM order_items

UNION ALL

SELECT
    'inventory_log',
    COUNT(*),
    MIN(log_id),
    MAX(log_id),
    MAX(log_id)::bigint + 1
FROM inventory_log;

\echo === 3. Existing identifier definitions ===

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    is_identity,
    identity_generation
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

ROLLBACK;