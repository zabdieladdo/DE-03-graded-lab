-- DE-03: Stage 01.3 — Referential integrity
-- Purpose: Quantify missing and unresolved relationships.
-- No data or schema modifications.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo '=== 1. Database identity ==='

SELECT current_database() AS database_name;

\echo '=== 2. Referential integrity summary ==='

WITH relationship_checks AS (
    SELECT
        'orders -> customers' AS relationship,
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE o.customer_id IS NULL
        ) AS null_references,
        COUNT(*) FILTER (
            WHERE o.customer_id IS NOT NULL
                AND c.customer_id IS NULL
        ) AS orphan_references,
        COUNT(c.customer_id) AS matched_references
    FROM orders AS o
    LEFT JOIN customers AS c
        ON o.customer_id = c.customer_id

    UNION ALL

    SELECT
        'order_items -> orders',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE oi.order_id IS NULL
        ),
        COUNT(*) FILTER (
            WHERE oi.order_id IS NOT NULL
                AND o.order_id IS NULL
        ),
        COUNT(o.order_id)
    FROM order_items AS oi
    LEFT JOIN orders AS o
        ON oi.order_id = o.order_id

    UNION ALL

    SELECT
        'order_items -> products',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE oi.product_id IS NULL
        ),
        COUNT(*) FILTER (
            WHERE oi.product_id IS NOT NULL
                AND p.product_id IS NULL
        ),
        COUNT(p.product_id)
    FROM order_items AS oi
    LEFT JOIN products AS p
        ON oi.product_id = p.product_id

    UNION ALL

    SELECT
        'inventory_log -> products',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE il.product_id IS NULL
        ),
        COUNT(*) FILTER (
            WHERE il.product_id IS NOT NULL
                AND p.product_id IS NULL
        ),
        COUNT(p.product_id)
    FROM inventory_log AS il
    LEFT JOIN products AS p
        ON il.product_id = p.product_id

    UNION ALL

    SELECT
        'products -> categories',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE p.category_id IS NULL
        ),
        COUNT(*) FILTER (
            WHERE p.category_id IS NOT NULL
                AND c.category_id IS NULL
        ),
        COUNT(c.category_id)
    FROM products AS p
    LEFT JOIN categories AS c
        ON p.category_id = c.category_id

    UNION ALL

    SELECT
        'categories -> parent categories',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE child.parent_id IS NULL
        ),
        COUNT(*) FILTER (
            WHERE child.parent_id IS NOT NULL
                AND parent.category_id IS NULL
        ),
        COUNT(parent.category_id)
    FROM categories AS child
    LEFT JOIN categories AS parent
        ON child.parent_id = parent.category_id
)
SELECT
    relationship,
    total_rows,
    matched_references,
    null_references,
    orphan_references,
    ROUND(
        100.0 * orphan_references
        / NULLIF(total_rows, 0),
        4
    ) AS orphan_percentage,
    total_rows
        - matched_references
        - null_references
        - orphan_references AS reconciliation_difference
FROM relationship_checks
ORDER BY orphan_references DESC, relationship;

ROLLBACK;