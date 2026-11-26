\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo === 1. Database and fixture safety ===

DO $test$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM products
        WHERE product_name LIKE 'RACE TEST FIXTURE%'
    ) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one race fixture';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM products
        WHERE product_id = 10323
          AND product_name = 'RACE TEST FIXTURE T4 trail'
          AND price = 100.00
    ) THEN
        RAISE EXCEPTION 'Expected audit fixture not found';
    END IF;
END;
$test$;

\echo === 2. Product stock ===

SELECT
    product_id,
    product_name,
    price,
    5 AS initial_stock,
    stock_quantity AS remaining_stock,
    5 - stock_quantity AS stock_deducted
FROM products
WHERE product_id = 10323;

\echo === 3. Individual purchase reconciliation ===

SELECT
    o.order_id,
    o.customer_id,
    o.status,
    o.total_amount,
    oi.order_item_id,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS item_value,
    il.log_id,
    il.change_qty,
    il.reason,
    il.note,
    CASE
        WHEN il.change_qty = -oi.quantity
         AND il.reason = 'sale'
         AND o.total_amount = oi.quantity * oi.unit_price
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
LEFT JOIN inventory_log il
    ON il.product_id = oi.product_id
   AND il.note = format('Order ID: %s', o.order_id)
WHERE oi.product_id = 10323
ORDER BY o.order_id, il.log_id;

\echo === 4. Independent aggregate reconciliation ===

WITH purchases AS (
    SELECT
        COUNT(*) AS item_count,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(quantity) AS units_sold,
        SUM(quantity * unit_price) AS item_value
    FROM order_items
    WHERE product_id = 10323
),
movements AS (
    SELECT
        COUNT(*) AS movement_count,
        SUM(change_qty) AS net_movement
    FROM inventory_log
    WHERE product_id = 10323
),
order_values AS (
    SELECT
        SUM(total_amount) AS order_value
    FROM orders
    WHERE order_id IN (
        SELECT order_id
        FROM order_items
        WHERE product_id = 10323
    )
)
SELECT
    p.product_id,
    5 AS initial_stock,
    p.stock_quantity AS remaining_stock,
    pu.order_count,
    pu.item_count,
    pu.units_sold,
    pu.item_value,
    ov.order_value,
    m.movement_count,
    m.net_movement,
    5 + m.net_movement AS calculated_stock
FROM products p
CROSS JOIN purchases pu
CROSS JOIN movements m
CROSS JOIN order_values ov
WHERE p.product_id = 10323;

\echo === 5. Automated audit assertions ===

DO $test$
DECLARE
    v_pid integer := 10323;
    v_order record;
    v_count bigint;
    v_total numeric;
BEGIN
    -- A01: Stock must be exhausted, not negative.

    IF (
        SELECT stock_quantity
        FROM products
        WHERE product_id = v_pid
    ) IS DISTINCT FROM 0 THEN
        RAISE EXCEPTION 'A01: Incorrect final stock';
    END IF;

    RAISE NOTICE 'PASS A01: Final stock = 0';

    -- A02: Exactly five distinct orders.

    SELECT COUNT(DISTINCT order_id)
    INTO v_count
    FROM order_items
    WHERE product_id = v_pid;

    IF v_count <> 5 THEN
        RAISE EXCEPTION 'A02: Expected 5 orders, found %', v_count;
    END IF;

    RAISE NOTICE 'PASS A02: Five distinct orders';

    -- A03: Exactly five order items.

    IF (
        SELECT COUNT(*)
        FROM order_items
        WHERE product_id = v_pid
    ) <> 5 THEN
        RAISE EXCEPTION 'A03: Incorrect item count';
    END IF;

    RAISE NOTICE 'PASS A03: Five order items';

    -- A04: Exactly five units sold.

    IF (
        SELECT SUM(quantity)
        FROM order_items
        WHERE product_id = v_pid
    ) IS DISTINCT FROM 5::bigint THEN
        RAISE EXCEPTION 'A04: Incorrect quantity sold';
    END IF;

    RAISE NOTICE 'PASS A04: Five units sold';

    -- A05: Correct captured price and quantity.

    IF EXISTS (
        SELECT 1
        FROM order_items
        WHERE product_id = v_pid
          AND (
              quantity IS DISTINCT FROM 1
              OR unit_price IS DISTINCT FROM 100.00
          )
    ) THEN
        RAISE EXCEPTION 'A05: Incorrect item quantity or price';
    END IF;

    RAISE NOTICE 'PASS A05: Correct quantities and prices';

    -- A06: Exactly five inventory movements.

    IF (
        SELECT COUNT(*)
        FROM inventory_log
        WHERE product_id = v_pid
    ) <> 5 THEN
        RAISE EXCEPTION 'A06: Incorrect movement count';
    END IF;

    RAISE NOTICE 'PASS A06: Five inventory movements';

    -- A07: Inventory quantities and reasons are correct.

    IF EXISTS (
        SELECT 1
        FROM inventory_log
        WHERE product_id = v_pid
          AND (
              change_qty IS DISTINCT FROM -1
              OR reason IS DISTINCT FROM 'sale'
              OR created_at IS NULL
          )
    ) THEN
        RAISE EXCEPTION 'A07: Incorrect inventory movement';
    END IF;

    RAISE NOTICE 'PASS A07: Movement quantities and reasons correct';

    -- A08: Inventory movement reconciles to remaining stock.

    SELECT SUM(change_qty)
    INTO v_total
    FROM inventory_log
    WHERE product_id = v_pid;

    IF v_total IS DISTINCT FROM -5::numeric THEN
        RAISE EXCEPTION 'A08: Incorrect net stock movement';
    END IF;

    RAISE NOTICE 'PASS A08: Net inventory movement = -5';

    -- A09: Each purchase has exactly one matching movement.

    FOR v_order IN
        SELECT DISTINCT order_id
        FROM order_items
        WHERE product_id = v_pid
    LOOP
        SELECT COUNT(*)
        INTO v_count
        FROM inventory_log
        WHERE product_id = v_pid
          AND note = format('Order ID: %s', v_order.order_id)
          AND change_qty = -1
          AND reason = 'sale';

        IF v_count <> 1 THEN
            RAISE EXCEPTION
                'A09: Order % has % matching movements',
                v_order.order_id,
                v_count;
        END IF;

        RAISE NOTICE
            'PASS A09: Order % has exactly one matching movement',
            v_order.order_id;
    END LOOP;

    -- A10: No unexpected additional items in these orders.

    IF EXISTS (
        SELECT 1
        FROM order_items
        WHERE order_id IN (
            SELECT order_id
            FROM order_items
            WHERE product_id = v_pid
        )
        AND product_id IS DISTINCT FROM v_pid
    ) THEN
        RAISE EXCEPTION 'A10: Unexpected additional order items';
    END IF;

    RAISE NOTICE 'PASS A10: No unexpected order items';

    -- A11: Individual order values and statuses.

    IF EXISTS (
        SELECT 1
        FROM order_items oi
        LEFT JOIN orders o
            ON o.order_id = oi.order_id
        WHERE oi.product_id = v_pid
          AND (
              o.order_id IS NULL
              OR o.total_amount IS DISTINCT FROM
                  oi.quantity * oi.unit_price
              OR o.status IS DISTINCT FROM 'completed'
              OR o.customer_id IS DISTINCT FROM (
                  SELECT MIN(customer_id) FROM customers
              )
          )
    ) THEN
        RAISE EXCEPTION 'A11: Incorrect order value, status or customer';
    END IF;

    RAISE NOTICE 'PASS A11: Individual orders reconcile';

    -- A12: Aggregate order value.

    SELECT SUM(total_amount)
    INTO v_total
    FROM orders
    WHERE order_id IN (
        SELECT order_id
        FROM order_items
        WHERE product_id = v_pid
    );

    IF v_total IS DISTINCT FROM 500.00 THEN
        RAISE EXCEPTION 'A12: Incorrect total order value';
    END IF;

    RAISE NOTICE 'PASS A12: Total order value = 500.00';

    RAISE NOTICE
        'RESULT: All 12 independent audit checks passed';
END;
$test$;

ROLLBACK;