-- DE-03: Kloud Kart
-- Stage 03.4: Purchase function regression tests
--
-- Tests successful purchases, controlled refusals,
-- stock consistency, financial consistency,
-- and inventory audit records.
--
-- All fixture changes are rolled back.
-- Sequence allocations are not rolled back.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN ISOLATION LEVEL READ COMMITTED;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Functional purchase tests ===

DO $test$

DECLARE
    v_customer_id bigint;
    v_product_id integer;

    v_missing_customer bigint;
    v_missing_product bigint;

    v_test record;
    v_result record;

    v_result_count integer;

    v_stock_before integer;
    v_stock_after integer;

    v_orders_before bigint;
    v_orders_after bigint;

    v_items_before bigint;
    v_items_after bigint;

    v_logs_before bigint;
    v_logs_after bigint;

    v_expected_total numeric;

    v_order_ids bigint[] := ARRAY[]::bigint[];

    v_passed integer := 0;
    v_successes integer := 0;
    v_refusals integer := 0;

BEGIN

    -- Safety guard.

    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect test database';
    END IF;


    -- Select an existing customer.

    SELECT MIN(c.customer_id)
    INTO v_customer_id
    FROM public.customers AS c;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'No test customer available';
    END IF;


    -- Allocate identifiers for the isolated fixture.
    -- Assumes no concurrent test writers.

    SELECT MAX(p.product_id)::bigint + 1000
    INTO v_product_id
    FROM public.products AS p;

    SELECT MAX(c.customer_id)::bigint + 1
    INTO v_missing_customer
    FROM public.customers AS c;

    v_missing_product := v_product_id::bigint + 1;


    -- Create a temporary test product.

    INSERT INTO public.products (
        product_id,
        product_name,
        category_id,
        price,
        stock_quantity,
        created_at
    )
    VALUES (
        v_product_id,
        'DE03 FUNCTIONAL TEST FIXTURE',
        NULL,
        100.00,
        5,
        CURRENT_TIMESTAMP
    );

    RAISE NOTICE
        'Fixture product: %, customer: %, stock: 5, price: 100.00',
        v_product_id,
        v_customer_id;


    -- Execute each scenario.

    FOR v_test IN

        SELECT *
        FROM (VALUES

            (
                1,
                'Purchase two units',
                v_customer_id,
                v_product_id::bigint,
                2,
                true,
                'Order placed successfully',
                3
            ),
            (
                2,
                'Insufficient stock',
                v_customer_id,
                v_product_id::bigint,
                4,
                false,
                'Out of stock',
                3
            ),
            (
                3,
                'Zero quantity',
                v_customer_id,
                v_product_id::bigint,
                0,
                false,
                'Quantity must be positive',
                3
            ),
            (
                4,
                'Negative quantity',
                v_customer_id,
                v_product_id::bigint,
                -1,
                false,
                'Quantity must be positive',
                3
            ),
            (
                5,
                'NULL quantity',
                v_customer_id,
                v_product_id::bigint,
                NULL::integer,
                false,
                'Quantity must be positive',
                3
            ),
            (
                6,
                'Invalid customer',
                v_missing_customer,
                v_product_id::bigint,
                1,
                false,
                'Customer not found',
                3
            ),
            (
                7,
                'Invalid product',
                v_customer_id,
                v_missing_product,
                1,
                false,
                'Product not found',
                3
            ),
            (
                8,
                'NULL customer',
                NULL::bigint,
                v_product_id::bigint,
                1,
                false,
                'Customer not found',
                3
            ),
            (
                9,
                'NULL product',
                v_customer_id,
                NULL::bigint,
                1,
                false,
                'Product not found',
                3
            ),
            (
                10,
                'Purchase remaining three units',
                v_customer_id,
                v_product_id::bigint,
                3,
                true,
                'Order placed successfully',
                0
            ),
            (
                11,
                'Purchase after sellout',
                v_customer_id,
                v_product_id::bigint,
                1,
                false,
                'Out of stock',
                0
            )

        ) AS cases (
            test_number,
            test_name,
            customer_id,
            product_id,
            quantity,
            expected_success,
            expected_message,
            expected_stock
        )

        ORDER BY test_number

    LOOP

        -- Capture state before the function call.

        SELECT p.stock_quantity
        INTO v_stock_before
        FROM public.products AS p
        WHERE p.product_id = v_product_id;

        SELECT COUNT(*)
        INTO v_orders_before
        FROM public.orders;

        SELECT COUNT(*)
        INTO v_items_before
        FROM public.order_items;

        SELECT COUNT(*)
        INTO v_logs_before
        FROM public.inventory_log;


        -- Execute the function exactly once.
        -- INTO STRICT requires exactly one result row.

        SELECT r.*
        INTO STRICT v_result
        FROM public.place_order(
            v_test.customer_id,
            v_test.product_id,
            v_test.quantity
        ) AS r;


        -- Verify the returned success indicator.

        IF v_result.success IS DISTINCT FROM
            v_test.expected_success THEN

            RAISE EXCEPTION
                'FAIL T%: unexpected success result: %',
                v_test.test_number,
                v_result.success;
        END IF;


        -- Verify the expected message.

        IF v_result.message IS NULL
            OR POSITION(
                LOWER(v_test.expected_message)
                IN LOWER(v_result.message)
            ) = 0 THEN

            RAISE EXCEPTION
                'FAIL T%: unexpected message: %',
                v_test.test_number,
                v_result.message;
        END IF;


        -- Capture database state after the call.

        SELECT p.stock_quantity
        INTO v_stock_after
        FROM public.products AS p
        WHERE p.product_id = v_product_id;

        SELECT COUNT(*)
        INTO v_orders_after
        FROM public.orders;

        SELECT COUNT(*)
        INTO v_items_after
        FROM public.order_items;

        SELECT COUNT(*)
        INTO v_logs_after
        FROM public.inventory_log;


        -- Verify expected remaining stock.

        IF v_stock_after IS DISTINCT FROM
            v_test.expected_stock THEN

            RAISE EXCEPTION
                'FAIL T%: expected stock %, found %',
                v_test.test_number,
                v_test.expected_stock,
                v_stock_after;
        END IF;


        IF v_test.expected_success THEN

            -- Successful purchases must return an ID.

            IF v_result.order_id IS NULL THEN
                RAISE EXCEPTION
                    'FAIL T%: missing successful order ID',
                    v_test.test_number;
            END IF;


            -- Successful IDs must not repeat.

            IF v_result.order_id = ANY(v_order_ids) THEN
                RAISE EXCEPTION
                    'FAIL T%: duplicate returned order ID',
                    v_test.test_number;
            END IF;


            -- Exactly one new record in each table.

            IF v_orders_after - v_orders_before <> 1
                OR v_items_after - v_items_before <> 1
                OR v_logs_after - v_logs_before <> 1 THEN

                RAISE EXCEPTION
                    'FAIL T%: incorrect purchase record counts',
                    v_test.test_number;
            END IF;


            -- Exact stock deduction.

            IF v_stock_before - v_stock_after
                <> v_test.quantity THEN

                RAISE EXCEPTION
                    'FAIL T%: incorrect stock deduction',
                    v_test.test_number;
            END IF;


            -- Verify order details.

            v_expected_total :=
                100.00 * v_test.quantity;

            SELECT COUNT(*)
            INTO v_result_count
            FROM public.orders AS o
            WHERE o.order_id = v_result.order_id
                AND o.customer_id = v_customer_id
                AND o.status = 'completed'
                AND o.total_amount = v_expected_total
                AND o.order_date IS NOT NULL;

            IF v_result_count <> 1 THEN
                RAISE EXCEPTION
                    'FAIL T%: incorrect order details',
                    v_test.test_number;
            END IF;


            -- Verify order item details.

            SELECT COUNT(*)
            INTO v_result_count
            FROM public.order_items AS oi
            WHERE oi.order_id = v_result.order_id
                AND oi.product_id = v_product_id
                AND oi.quantity = v_test.quantity
                AND oi.unit_price = 100.00;

            IF v_result_count <> 1 THEN
                RAISE EXCEPTION
                    'FAIL T%: incorrect order item',
                    v_test.test_number;
            END IF;


            -- Verify the inventory movement.

            SELECT COUNT(*)
            INTO v_result_count
            FROM public.inventory_log AS il
            WHERE il.product_id = v_product_id
                AND il.change_qty = -v_test.quantity
                AND il.reason = 'sale'
                AND il.created_at IS NOT NULL
                AND il.note = format(
                    'Order ID: %s',
                    v_result.order_id
                );

            IF v_result_count <> 1 THEN
                RAISE EXCEPTION
                    'FAIL T%: incorrect inventory movement',
                    v_test.test_number;
            END IF;


            v_order_ids := array_append(
                v_order_ids,
                v_result.order_id
            );

            v_successes := v_successes + 1;


        ELSE

            -- Refusals must not return an order ID.

            IF v_result.order_id IS NOT NULL THEN
                RAISE EXCEPTION
                    'FAIL T%: refusal returned an order ID',
                    v_test.test_number;
            END IF;


            -- Refusals must not change stock or
            -- create purchase records.

            IF v_stock_after IS DISTINCT FROM v_stock_before
                OR v_orders_after <> v_orders_before
                OR v_items_after <> v_items_before
                OR v_logs_after <> v_logs_before THEN

                RAISE EXCEPTION
                    'FAIL T%: refused purchase changed state',
                    v_test.test_number;
            END IF;

            v_refusals := v_refusals + 1;

        END IF;


        v_passed := v_passed + 1;

        RAISE NOTICE
            'PASS T%: % | success=% | order_id=% | stock=% | message=%',
            v_test.test_number,
            v_test.test_name,
            v_result.success,
            v_result.order_id,
            v_stock_after,
            v_result.message;

    END LOOP;


    -- Assert the complete scenario count.

    IF v_passed <> 11
        OR v_successes <> 2
        OR v_refusals <> 9 THEN

        RAISE EXCEPTION
            'FAIL: unexpected final test totals';
    END IF;


    RAISE NOTICE
        'RESULT: % of 11 functional tests passed',
        v_passed;

    RAISE NOTICE
        'Successful purchases: %, refusals: %',
        v_successes,
        v_refusals;

    RAISE NOTICE
        'Generated order IDs: %',
        v_order_ids;

END;

$test$;


\echo === 3. Purchase reconciliation before rollback ===

SELECT
    p.product_id,
    p.stock_quantity AS remaining_stock,
    COUNT(DISTINCT o.order_id) AS successful_orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.unit_price) AS item_value,
    SUM(o.total_amount) AS order_value

FROM public.products AS p

JOIN public.order_items AS oi
    ON oi.product_id = p.product_id

JOIN public.orders AS o
    ON o.order_id = oi.order_id

WHERE p.product_name = 'DE03 FUNCTIONAL TEST FIXTURE'

GROUP BY
    p.product_id,
    p.stock_quantity;


\echo === 4. Inventory movement reconciliation ===

SELECT
    p.product_id,
    COUNT(il.log_id) AS movement_count,
    SUM(il.change_qty) AS net_stock_movement

FROM public.products AS p

JOIN public.inventory_log AS il
    ON il.product_id = p.product_id

WHERE p.product_name = 'DE03 FUNCTIONAL TEST FIXTURE'

GROUP BY p.product_id;


\echo === 5. Roll back all fixture changes ===

ROLLBACK;


\echo === 6. Baseline reconciliation after rollback ===

WITH baseline(table_name, expected_rows) AS (

    VALUES
        ('categories', 94::bigint),
        ('products', 4023::bigint),
        ('customers', 40420::bigint),
        ('orders', 159384::bigint),
        ('order_items', 336559::bigint),
        ('inventory_log', 282352::bigint)

),

actual AS (

    SELECT 'categories' AS table_name,
           COUNT(*) AS actual_rows
    FROM public.categories

    UNION ALL

    SELECT 'products', COUNT(*)
    FROM public.products

    UNION ALL

    SELECT 'customers', COUNT(*)
    FROM public.customers

    UNION ALL

    SELECT 'orders', COUNT(*)
    FROM public.orders

    UNION ALL

    SELECT 'order_items', COUNT(*)
    FROM public.order_items

    UNION ALL

    SELECT 'inventory_log', COUNT(*)
    FROM public.inventory_log

)

SELECT
    b.table_name,
    b.expected_rows,
    a.actual_rows,
    a.actual_rows - b.expected_rows AS difference,
    CASE
        WHEN a.actual_rows = b.expected_rows
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result

FROM baseline AS b

JOIN actual AS a
    USING (table_name)

ORDER BY b.table_name;


\echo === 7. Fixture cleanup verification ===

SELECT COUNT(*) AS remaining_test_products
FROM public.products
WHERE product_name = 'DE03 FUNCTIONAL TEST FIXTURE';