-- DE-03: Kloud Kart
-- Stage 03.8: Retained audit fixture cleanup
--
-- Removes only the verified records from the
-- retained Test 4 execution on 2026-11-26.
--
-- Do not reuse these identifiers for future runs.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

SET LOCAL lock_timeout = '5s';

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


-- Prevent concurrent modifications during cleanup.

LOCK TABLE
    public.categories,
    public.customers,
    public.products,
    public.orders,
    public.order_items,
    public.inventory_log
IN SHARE ROW EXCLUSIVE MODE;


\echo === 2. Verify exact retained fixture records ===

DO $guard$

DECLARE
    v_count bigint;

BEGIN

    -- Confirm the expected pre-cleanup table counts.

    IF (SELECT COUNT(*) FROM categories) <> 94
       OR (SELECT COUNT(*) FROM customers) <> 40420
       OR (SELECT COUNT(*) FROM products) <> 4024
       OR (SELECT COUNT(*) FROM orders) <> 159389
       OR (SELECT COUNT(*) FROM order_items) <> 336564
       OR (SELECT COUNT(*) FROM inventory_log) <> 282357
    THEN
        RAISE EXCEPTION
            'Unexpected pre-cleanup table counts';
    END IF;

    RAISE NOTICE
        'PASS: Expected retained fixture counts confirmed';


    -- Confirm the exact product fixture.

    IF NOT EXISTS (
        SELECT 1
        FROM products
        WHERE product_id = 10323
          AND product_name = 'RACE TEST FIXTURE T4 trail'
          AND category_id IS NULL
          AND price = 100.00
          AND stock_quantity = 0
    ) THEN
        RAISE EXCEPTION 'Expected fixture product not found';
    END IF;


    -- Confirm there are no additional race fixtures.

    IF (
        SELECT COUNT(*)
        FROM products
        WHERE product_name LIKE 'RACE TEST FIXTURE%'
    ) <> 1 THEN
        RAISE EXCEPTION 'Unexpected race fixtures';
    END IF;


    -- Confirm exact order identifiers and values.

    SELECT COUNT(*)
    INTO v_count
    FROM orders
    WHERE order_id IN (
        659470, 659471, 659472, 659473, 659474
    )
      AND customer_id = 100001
      AND status = 'completed'
      AND total_amount = 100.00;

    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Expected audit orders not found';
    END IF;


    -- Confirm exact order items.

    SELECT COUNT(*)
    INTO v_count
    FROM order_items
    WHERE order_item_id IN (
        1236645, 1236646, 1236647,
        1236648, 1236649
    )
      AND product_id = 10323
      AND order_id IN (
          659470, 659471, 659472, 659473, 659474
      )
      AND quantity = 1
      AND unit_price = 100.00;

    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Expected audit order items not found';
    END IF;


    -- Confirm exact inventory movements.

    SELECT COUNT(*)
    INTO v_count
    FROM inventory_log
    WHERE log_id IN (
        982573, 982574, 982575, 982576, 982577
    )
      AND product_id = 10323
      AND change_qty = -1
      AND reason = 'sale';

    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Expected inventory movements not found';
    END IF;


    -- Confirm no unrelated records reference the fixture.

    IF (
        SELECT COUNT(*)
        FROM order_items
        WHERE product_id = 10323
           OR order_id IN (
               659470, 659471, 659472,
               659473, 659474
           )
    ) <> 5 THEN
        RAISE EXCEPTION 'Unexpected order item references';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM inventory_log
        WHERE product_id = 10323
    ) <> 5 THEN
        RAISE EXCEPTION 'Unexpected inventory references';
    END IF;

    RAISE NOTICE
        'PASS: All 16 retained fixture records verified';

END;

$guard$;


\echo === 3. Remove verified fixture records ===

DO $cleanup$

DECLARE
    v_deleted bigint;

BEGIN

    -- Remove dependent order items first.

    DELETE FROM order_items
    WHERE order_item_id IN (
        1236645, 1236646, 1236647,
        1236648, 1236649
    )
      AND product_id = 10323;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted <> 5 THEN
        RAISE EXCEPTION 'Unexpected order item deletion count';
    END IF;

    RAISE NOTICE 'Removed order items: %', v_deleted;


    -- Remove fixture inventory movements.

    DELETE FROM inventory_log
    WHERE log_id IN (
        982573, 982574, 982575, 982576, 982577
    )
      AND product_id = 10323;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted <> 5 THEN
        RAISE EXCEPTION 'Unexpected inventory deletion count';
    END IF;

    RAISE NOTICE 'Removed inventory movements: %', v_deleted;


    -- Remove fixture orders.

    DELETE FROM orders
    WHERE order_id IN (
        659470, 659471, 659472, 659473, 659474
    );

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted <> 5 THEN
        RAISE EXCEPTION 'Unexpected order deletion count';
    END IF;

    RAISE NOTICE 'Removed orders: %', v_deleted;


    -- Remove the fixture product last.

    DELETE FROM products
    WHERE product_id = 10323
      AND product_name = 'RACE TEST FIXTURE T4 trail';

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted <> 1 THEN
        RAISE EXCEPTION 'Unexpected product deletion count';
    END IF;

    RAISE NOTICE 'Removed fixture products: %', v_deleted;

END;

$cleanup$;


\echo === 4. Verify baseline before committing ===

DO $verify$

DECLARE
    v_table record;
    v_actual bigint;

BEGIN

    FOR v_table IN

        SELECT *
        FROM (VALUES
            ('categories', 94::bigint),
            ('customers', 40420::bigint),
            ('products', 4023::bigint),
            ('orders', 159384::bigint),
            ('order_items', 336559::bigint),
            ('inventory_log', 282352::bigint)
        ) AS baseline(table_name, expected_rows)

    LOOP

        EXECUTE format(
            'SELECT COUNT(*) FROM public.%I',
            v_table.table_name
        )
        INTO v_actual;

        IF v_actual <> v_table.expected_rows THEN
            RAISE EXCEPTION
                'Baseline mismatch: %, expected %, found %',
                v_table.table_name,
                v_table.expected_rows,
                v_actual;
        END IF;

        RAISE NOTICE
            'PASS: % baseline count = %',
            v_table.table_name,
            v_actual;

    END LOOP;


    IF EXISTS (
        SELECT 1
        FROM products
        WHERE product_id = 10323
           OR product_name LIKE 'RACE TEST FIXTURE%'
    ) THEN
        RAISE EXCEPTION 'Fixture product remains';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM orders
        WHERE order_id BETWEEN 659470 AND 659474
    ) THEN
        RAISE EXCEPTION 'Fixture orders remain';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM order_items
        WHERE product_id = 10323
           OR order_id BETWEEN 659470 AND 659474
           OR order_item_id BETWEEN 1236645 AND 1236649
    ) THEN
        RAISE EXCEPTION 'Fixture order items remain';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM inventory_log
        WHERE product_id = 10323
           OR log_id BETWEEN 982573 AND 982577
    ) THEN
        RAISE EXCEPTION 'Fixture inventory movements remain';
    END IF;


    IF (
        SELECT COUNT(*)
        FROM products
        WHERE stock_quantity < 0
    ) <> 14 THEN
        RAISE EXCEPTION
            'Historical negative-stock count changed';
    END IF;


    RAISE NOTICE
        'PASS: All retained fixture records removed';

    RAISE NOTICE
        'PASS: All 14 historical negative-stock products preserved';

    RAISE NOTICE
        'RESULT: All cleanup assertions passed';

END;

$verify$;


COMMIT;


\echo === 5. Final committed baseline ===

SELECT 'categories' AS table_name, COUNT(*) AS row_count
FROM categories

UNION ALL
SELECT 'customers', COUNT(*) FROM customers

UNION ALL
SELECT 'products', COUNT(*) FROM products

UNION ALL
SELECT 'orders', COUNT(*) FROM orders

UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items

UNION ALL
SELECT 'inventory_log', COUNT(*) FROM inventory_log;


\echo === 6. Identifier sequence state ===

SELECT
    'orders' AS table_name,
    last_value,
    is_called
FROM orders_order_id_seq

UNION ALL

SELECT
    'order_items',
    last_value,
    is_called
FROM order_items_order_item_id_seq

UNION ALL

SELECT
    'inventory_log',
    last_value,
    is_called
FROM inventory_log_log_id_seq;