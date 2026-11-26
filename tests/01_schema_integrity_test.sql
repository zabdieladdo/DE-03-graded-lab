-- DE-03: Kloud Kart
-- Stage 02.6: Combined schema integrity tests
--
-- Purpose:
-- Verify foreign keys, numerical constraints
-- and automatic identifier generation.
--
-- All test rows and updates are rolled back.
-- Sequence allocations are not rolled back.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Functional integrity tests ===

DO $$
DECLARE
    v_customer_id integer;
    v_product_id integer;
    v_category_id integer;

    v_order_id integer;
    v_item_id integer;
    v_log_id integer;

    v_max_order integer;
    v_max_item integer;
    v_max_log integer;

    v_missing_customer integer;
    v_missing_product integer;
    v_missing_order integer;
    v_missing_category integer;

    v_test record;
    v_constraint text;
    v_sqlstate text;
    v_passed integer := 0;

BEGIN
    -- Safety guard: run only against the graded lab.

    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect test database';
    END IF;

    -- Select existing valid references.

    SELECT MIN(customer_id)
    INTO v_customer_id
    FROM customers;

    SELECT MIN(product_id)
    INTO v_product_id
    FROM products
    WHERE stock_quantity >= 0
        AND price >= 0;

    SELECT MIN(category_id)
    INTO v_category_id
    FROM categories
    WHERE parent_id IS NULL;

    IF v_customer_id IS NULL
        OR v_product_id IS NULL
        OR v_category_id IS NULL THEN

        RAISE EXCEPTION
            'Required test references unavailable';
    END IF;

    -- Record current maximum identifiers.

    SELECT MAX(order_id)
    INTO v_max_order
    FROM orders;

    SELECT MAX(order_item_id)
    INTO v_max_item
    FROM order_items;

    SELECT MAX(log_id)
    INTO v_max_log
    FROM inventory_log;

    -- Generate a test order automatically.
    -- Zero order totals must be permitted.

    INSERT INTO orders (
        customer_id,
        order_date,
        status,
        total_amount
    )
    VALUES (
        v_customer_id,
        CURRENT_TIMESTAMP,
        'pending',
        0
    )
    RETURNING order_id INTO v_order_id;

    IF v_order_id <= v_max_order THEN
        RAISE EXCEPTION
            'Generated order ID is unsafe';
    END IF;

    RAISE NOTICE
        'PASS: Automatic order ID = %',
        v_order_id;

    -- Generate a test order item automatically.
    -- Zero item prices must be permitted.

    INSERT INTO order_items (
        order_id,
        product_id,
        quantity,
        unit_price
    )
    VALUES (
        v_order_id,
        v_product_id,
        1,
        0
    )
    RETURNING order_item_id INTO v_item_id;

    IF v_item_id <= v_max_item THEN
        RAISE EXCEPTION
            'Generated order item ID is unsafe';
    END IF;

    RAISE NOTICE
        'PASS: Automatic order item ID = %',
        v_item_id;

    -- Generate a test inventory log automatically.

    INSERT INTO inventory_log (
        product_id,
        change_qty,
        reason,
        created_at,
        note
    )
    VALUES (
        v_product_id,
        0,
        'stock_take',
        CURRENT_TIMESTAMP,
        'Temporary schema integrity test'
    )
    RETURNING log_id INTO v_log_id;

    IF v_log_id <= v_max_log THEN
        RAISE EXCEPTION
            'Generated inventory log ID is unsafe';
    END IF;

    RAISE NOTICE
        'PASS: Automatic inventory log ID = %',
        v_log_id;

    -- Calculate references that do not exist.
    -- This is a controlled, isolated lab test.

    SELECT MAX(customer_id) + 1
    INTO v_missing_customer
    FROM customers;

    SELECT MAX(product_id) + 1
    INTO v_missing_product
    FROM products;

    SELECT MAX(order_id) + 1
    INTO v_missing_order
    FROM orders;

    SELECT MAX(category_id) + 1
    INTO v_missing_category
    FROM categories;

    -- Each test specifies:
    -- description, SQL statement, expected
    -- constraint name and expected SQLSTATE.

    FOR v_test IN

        SELECT *
        FROM (VALUES

            -- Foreign key tests.

            (
                'Invalid order customer',
                format(
                    'UPDATE orders SET customer_id = %s
                     WHERE order_id = %s',
                    v_missing_customer, v_order_id
                ),
                'fk_orders_customer',
                '23503'
            ),
            (
                'Invalid order item order',
                format(
                    'UPDATE order_items SET order_id = %s
                     WHERE order_item_id = %s',
                    v_missing_order, v_item_id
                ),
                'fk_order_items_order',
                '23503'
            ),
            (
                'Invalid order item product',
                format(
                    'UPDATE order_items SET product_id = %s
                     WHERE order_item_id = %s',
                    v_missing_product, v_item_id
                ),
                'fk_order_items_product',
                '23503'
            ),
            (
                'Invalid inventory product',
                format(
                    'UPDATE inventory_log SET product_id = %s
                     WHERE log_id = %s',
                    v_missing_product, v_log_id
                ),
                'fk_inventory_log_product',
                '23503'
            ),
            (
                'Invalid product category',
                format(
                    'UPDATE products SET category_id = %s
                     WHERE product_id = %s',
                    v_missing_category, v_product_id
                ),
                'fk_products_category',
                '23503'
            ),
            (
                'Invalid category parent',
                format(
                    'UPDATE categories SET parent_id = %s
                     WHERE category_id = %s',
                    v_missing_category, v_category_id
                ),
                'fk_categories_parent',
                '23503'
            ),

            -- Numerical value tests.

            (
                'Zero order quantity',
                format(
                    'UPDATE order_items SET quantity = 0
                     WHERE order_item_id = %s',
                    v_item_id
                ),
                'chk_order_items_quantity',
                '23514'
            ),
            (
                'Negative product stock',
                format(
                    'UPDATE products SET stock_quantity = -1
                     WHERE product_id = %s',
                    v_product_id
                ),
                'chk_products_stock',
                '23514'
            ),
            (
                'Negative product price',
                format(
                    'UPDATE products SET price = -1
                     WHERE product_id = %s',
                    v_product_id
                ),
                'chk_products_price',
                '23514'
            ),
            (
                'Negative order item price',
                format(
                    'UPDATE order_items SET unit_price = -1
                     WHERE order_item_id = %s',
                    v_item_id
                ),
                'chk_order_items_unit_price',
                '23514'
            ),
            (
                'Negative order total',
                format(
                    'UPDATE orders SET total_amount = -1
                     WHERE order_id = %s',
                    v_order_id
                ),
                'chk_orders_total_amount',
                '23514'
            ),

            -- NULL value tests.

            (
                'NULL order quantity',
                format(
                    'UPDATE order_items SET quantity = NULL
                     WHERE order_item_id = %s',
                    v_item_id
                ),
                'chk_order_items_quantity',
                '23514'
            ),
            (
                'NULL product stock',
                format(
                    'UPDATE products SET stock_quantity = NULL
                     WHERE product_id = %s',
                    v_product_id
                ),
                'chk_products_stock',
                '23514'
            ),
            (
                'NULL product price',
                format(
                    'UPDATE products SET price = NULL
                     WHERE product_id = %s',
                    v_product_id
                ),
                'chk_products_price',
                '23514'
            ),
            (
                'NULL order item price',
                format(
                    'UPDATE order_items SET unit_price = NULL
                     WHERE order_item_id = %s',
                    v_item_id
                ),
                'chk_order_items_unit_price',
                '23514'
            ),
            (
                'NULL order total',
                format(
                    'UPDATE orders SET total_amount = NULL
                     WHERE order_id = %s',
                    v_order_id
                ),
                'chk_orders_total_amount',
                '23514'
            )

        ) AS test_cases (
            test_name,
            test_sql,
            expected_constraint,
            expected_sqlstate
        )

    LOOP
        BEGIN
            EXECUTE v_test.test_sql;

            -- Reaching this statement means the
            -- invalid operation was not rejected.

            RAISE EXCEPTION
                'FAIL: % was accepted',
                v_test.test_name;

        EXCEPTION
            WHEN foreign_key_violation
                OR check_violation THEN

                GET STACKED DIAGNOSTICS
                    v_constraint = CONSTRAINT_NAME,
                    v_sqlstate = RETURNED_SQLSTATE;

                IF v_constraint IS DISTINCT FROM
                    v_test.expected_constraint

                    OR v_sqlstate IS DISTINCT FROM
                    v_test.expected_sqlstate THEN

                    RAISE EXCEPTION
                        'FAIL: % rejected by unexpected constraint % (%)',
                        v_test.test_name,
                        v_constraint,
                        v_sqlstate;
                END IF;

                v_passed := v_passed + 1;

                RAISE NOTICE
                    'PASS: % rejected by % (%)',
                    v_test.test_name,
                    v_constraint,
                    v_sqlstate;
        END;
    END LOOP;

    -- Positive boundary tests.
    -- These values must remain permissible.

    UPDATE products
    SET stock_quantity = 0
    WHERE product_id = v_product_id;

    RAISE NOTICE
        'PASS: Zero product stock accepted';

    UPDATE products
    SET price = 0
    WHERE product_id = v_product_id;

    RAISE NOTICE
        'PASS: Zero product price accepted';

    RAISE NOTICE
        'PASS: Zero order item price accepted';

    RAISE NOTICE
        'PASS: Zero order total accepted';

    RAISE NOTICE
        'PASS: Zero inventory movement accepted';

    -- Final negative-test assertion.

    IF v_passed <> 16 THEN
        RAISE EXCEPTION
            'Expected 16 rejection tests, passed %',
            v_passed;
    END IF;

    RAISE NOTICE
        'RESULT: % of 16 rejection tests passed',
        v_passed;

END;
$$;

\echo === 3. Roll back test changes ===

ROLLBACK;

\echo === 4. Baseline row counts after rollback ===

SELECT 'categories' AS table_name,
       COUNT(*) AS row_count
FROM categories

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'customers', COUNT(*)
FROM customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'inventory_log', COUNT(*)
FROM inventory_log;