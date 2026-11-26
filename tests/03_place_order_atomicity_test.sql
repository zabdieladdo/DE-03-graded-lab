-- DE-03: Kloud Kart
-- Stage 03.5: Purchase failure atomicity
--
-- Inject a failure at the final inventory write.
-- Verify that preceding purchase changes are undone.
--
-- All test objects and records are rolled back.
-- Sequence allocations are not rolled back.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN ISOLATION LEVEL READ COMMITTED;

\echo === 1. Database identity and safety guard ===

SELECT current_database() AS database_name;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect test database';
    END IF;
END;
$guard$;


\echo === 2. Create controlled failure fixture ===

CREATE TEMP TABLE atomicity_fixture (
    product_id integer NOT NULL,
    customer_id bigint NOT NULL,
    initial_stock integer NOT NULL,
    unit_price numeric(12,2) NOT NULL
) ON COMMIT DROP;


INSERT INTO atomicity_fixture
SELECT
    (SELECT MAX(product_id) + 1000
     FROM public.products),
    (SELECT MIN(customer_id)
     FROM public.customers),
    5,
    100.00;


INSERT INTO public.products (
    product_id,
    product_name,
    category_id,
    price,
    stock_quantity,
    created_at
)
SELECT
    product_id,
    'DE03 ATOMICITY TEST FIXTURE',
    NULL,
    unit_price,
    initial_stock,
    CURRENT_TIMESTAMP
FROM atomicity_fixture;


SELECT *
FROM atomicity_fixture;


\echo === 3. Install failure-injection trigger ===

CREATE FUNCTION public.de03_test_fail_inventory()
RETURNS trigger
LANGUAGE plpgsql
AS $trigger$

DECLARE
    v_fixture record;
    v_stock integer;
    v_order_id bigint;
    v_order_count bigint;
    v_item_count bigint;

BEGIN

    SELECT *
    INTO STRICT v_fixture
    FROM pg_temp.atomicity_fixture;


    -- Do not reject unrelated inventory movements.

    IF NEW.product_id <> v_fixture.product_id THEN
        RETURN NEW;
    END IF;


    -- Confirm stock has already been deducted.

    SELECT p.stock_quantity
    INTO STRICT v_stock
    FROM public.products AS p
    WHERE p.product_id = v_fixture.product_id;

    IF v_stock IS DISTINCT FROM 3 THEN
        RAISE EXCEPTION
            'Unexpected stock before injected failure: %',
            v_stock;
    END IF;


    RAISE NOTICE
        'PASS A01: Stock deduction observed before failure: %',
        v_stock;


    -- Recover the order reference from the note.

    v_order_id := substring(
        NEW.note FROM '^Order ID: ([0-9]+)$'
    )::bigint;

    IF v_order_id IS NULL THEN
        RAISE EXCEPTION
            'Missing order reference before injected failure';
    END IF;


    -- Confirm the order has already been created.

    SELECT COUNT(*)
    INTO v_order_count
    FROM public.orders AS o
    WHERE o.order_id = v_order_id
        AND o.customer_id = v_fixture.customer_id
        AND o.total_amount = 200.00
        AND o.status = 'completed';

    IF v_order_count <> 1 THEN
        RAISE EXCEPTION
            'Expected order not found before injected failure';
    END IF;


    RAISE NOTICE
        'PASS A02: Order % exists before failure',
        v_order_id;


    -- Confirm the order item has already been created.

    SELECT COUNT(*)
    INTO v_item_count
    FROM public.order_items AS oi
    WHERE oi.order_id = v_order_id
        AND oi.product_id = v_fixture.product_id
        AND oi.quantity = 2
        AND oi.unit_price = 100.00;

    IF v_item_count <> 1 THEN
        RAISE EXCEPTION
            'Expected order item not found before failure';
    END IF;


    RAISE NOTICE
        'PASS A03: Order item exists before failure';


    -- Deliberately reject the final inventory write.

    RAISE EXCEPTION
        USING
            ERRCODE = 'P0001',
            MESSAGE = 'DE03_INJECTED_INVENTORY_FAILURE';

END;

$trigger$;


CREATE TRIGGER de03_test_inventory_failure
BEFORE INSERT ON public.inventory_log
FOR EACH ROW
EXECUTE FUNCTION public.de03_test_fail_inventory();


\echo === 4. Execute purchase with injected failure ===

DO $test$

DECLARE
    v_fixture record;
    v_result record;

    v_sqlstate text;
    v_error_message text;
    v_expected_failure boolean := false;

    v_stock_before integer;
    v_stock_after integer;

    v_orders_before bigint;
    v_orders_after bigint;

    v_items_before bigint;
    v_items_after bigint;

    v_logs_before bigint;
    v_logs_after bigint;

BEGIN

    SELECT *
    INTO STRICT v_fixture
    FROM pg_temp.atomicity_fixture;


    -- Capture the state before purchase.

    SELECT stock_quantity
    INTO STRICT v_stock_before
    FROM public.products
    WHERE product_id = v_fixture.product_id;

    SELECT COUNT(*)
    INTO v_orders_before
    FROM public.orders;

    SELECT COUNT(*)
    INTO v_items_before
    FROM public.order_items;

    SELECT COUNT(*)
    INTO v_logs_before
    FROM public.inventory_log;


    -- Exception block creates a subtransaction.
    -- The failed purchase must be undone.

    BEGIN

        SELECT r.*
        INTO STRICT v_result
        FROM public.place_order(
            v_fixture.customer_id,
            v_fixture.product_id::bigint,
            2
        ) AS r;

        RAISE EXCEPTION
            'FAIL: Purchase returned instead of propagating failure';

    EXCEPTION

        WHEN SQLSTATE 'P0001' THEN

            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_error_message = MESSAGE_TEXT;

            IF v_error_message IS DISTINCT FROM
                'DE03_INJECTED_INVENTORY_FAILURE' THEN

                RAISE;
            END IF;

            v_expected_failure := true;

    END;


    IF NOT v_expected_failure THEN
        RAISE EXCEPTION
            'FAIL: Expected inventory failure not observed';
    END IF;


    RAISE NOTICE
        'PASS A04: Expected failure propagated (%) %',
        v_sqlstate,
        v_error_message;


    -- Inspect the database after the failed call.

    SELECT stock_quantity
    INTO STRICT v_stock_after
    FROM public.products
    WHERE product_id = v_fixture.product_id;

    SELECT COUNT(*)
    INTO v_orders_after
    FROM public.orders;

    SELECT COUNT(*)
    INTO v_items_after
    FROM public.order_items;

    SELECT COUNT(*)
    INTO v_logs_after
    FROM public.inventory_log;


    -- Assert that stock has been restored.

    IF v_stock_after IS DISTINCT FROM v_stock_before
        OR v_stock_after IS DISTINCT FROM 5 THEN

        RAISE EXCEPTION
            'FAIL A05: Stock not restored';
    END IF;


    RAISE NOTICE
        'PASS A05: Stock restored from failed purchase: %',
        v_stock_after;


    -- Assert that the order was rolled back.

    IF v_orders_after <> v_orders_before THEN
        RAISE EXCEPTION
            'FAIL A06: Partial order remains';
    END IF;

    RAISE NOTICE
        'PASS A06: Order count difference = %',
        v_orders_after - v_orders_before;


    -- Assert that the order item was rolled back.

    IF v_items_after <> v_items_before THEN
        RAISE EXCEPTION
            'FAIL A07: Partial order item remains';
    END IF;

    RAISE NOTICE
        'PASS A07: Order item count difference = %',
        v_items_after - v_items_before;


    -- Assert that no inventory log remains.

    IF v_logs_after <> v_logs_before THEN
        RAISE EXCEPTION
            'FAIL A08: Unexpected inventory movement remains';
    END IF;

    RAISE NOTICE
        'PASS A08: Inventory log count difference = %',
        v_logs_after - v_logs_before;


    RAISE NOTICE
        'RESULT: Failure atomicity assertions passed';

END;

$test$;


\echo === 5. Remove injected failure ===

DROP TRIGGER de03_test_inventory_failure
ON public.inventory_log;

DROP FUNCTION public.de03_test_fail_inventory();


\echo === 6. Verify recovery with successful purchase ===

DO $recovery$

DECLARE
    v_fixture record;
    v_result record;
    v_stock integer;
    v_count bigint;

BEGIN

    SELECT *
    INTO STRICT v_fixture
    FROM pg_temp.atomicity_fixture;


    SELECT r.*
    INTO STRICT v_result
    FROM public.place_order(
        v_fixture.customer_id,
        v_fixture.product_id::bigint,
        2
    ) AS r;


    IF v_result.success IS DISTINCT FROM true
        OR v_result.order_id IS NULL THEN

        RAISE EXCEPTION
            'FAIL A09: Recovery purchase unsuccessful';
    END IF;


    SELECT stock_quantity
    INTO STRICT v_stock
    FROM public.products
    WHERE product_id = v_fixture.product_id;


    IF v_stock IS DISTINCT FROM 3 THEN
        RAISE EXCEPTION
            'FAIL A09: Incorrect recovery stock';
    END IF;


    SELECT COUNT(*)
    INTO v_count
    FROM public.orders AS o
    JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_id = v_result.order_id
        AND o.customer_id = v_fixture.customer_id
        AND o.total_amount = 200.00
        AND o.status = 'completed'
        AND oi.product_id = v_fixture.product_id
        AND oi.quantity = 2
        AND oi.unit_price = 100.00;


    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'FAIL A09: Incorrect recovery order or item';
    END IF;


    SELECT COUNT(*)
    INTO v_count
    FROM public.inventory_log AS il
    WHERE il.product_id = v_fixture.product_id
        AND il.change_qty = -2
        AND il.reason = 'sale'
        AND il.note = format(
            'Order ID: %s',
            v_result.order_id
        );


    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'FAIL A09: Incorrect recovery inventory log';
    END IF;


    RAISE NOTICE
        'PASS A09: Recovery purchase successful, order %, stock %',
        v_result.order_id,
        v_stock;

END;

$recovery$;


\echo === 7. Roll back all test changes ===

ROLLBACK;


\echo === 8. Verify cleanup and baseline ===

DO $cleanup$

DECLARE
    v_table record;
    v_actual bigint;

BEGIN

    IF EXISTS (
        SELECT 1
        FROM public.products
        WHERE product_name =
            'DE03 ATOMICITY TEST FIXTURE'
    ) THEN

        RAISE EXCEPTION
            'FAIL: Test product remains';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid =
            'public.inventory_log'::regclass
            AND tgname =
                'de03_test_inventory_failure'
    ) THEN

        RAISE EXCEPTION
            'FAIL: Failure-injection trigger remains';
    END IF;


    IF to_regprocedure(
        'public.de03_test_fail_inventory()'
    ) IS NOT NULL THEN

        RAISE EXCEPTION
            'FAIL: Failure-injection function remains';
    END IF;


    IF to_regclass(
        'pg_temp.atomicity_fixture'
    ) IS NOT NULL THEN

        RAISE EXCEPTION
            'FAIL: Temporary fixture table remains';
    END IF;


    -- Automatically assert baseline counts.

    FOR v_table IN

        SELECT *
        FROM (VALUES
            ('categories', 94::bigint),
            ('products', 4023::bigint),
            ('customers', 40420::bigint),
            ('orders', 159384::bigint),
            ('order_items', 336559::bigint),
            ('inventory_log', 282352::bigint)
        ) AS baseline (
            table_name,
            expected_rows
        )

    LOOP

        EXECUTE format(
            'SELECT COUNT(*) FROM public.%I',
            v_table.table_name
        )
        INTO v_actual;


        IF v_actual <> v_table.expected_rows THEN
            RAISE EXCEPTION
                'FAIL: % expected %, found %',
                v_table.table_name,
                v_table.expected_rows,
                v_actual;
        END IF;


        RAISE NOTICE
            'PASS: % baseline count = %',
            v_table.table_name,
            v_actual;

    END LOOP;


    RAISE NOTICE
        'PASS A10: All fixtures and test objects removed';

    RAISE NOTICE
        'RESULT: All 10 atomicity test assertions passed';

END;

$cleanup$;