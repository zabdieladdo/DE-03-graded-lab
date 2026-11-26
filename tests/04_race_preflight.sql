\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

SELECT current_database() AS database_name;

SHOW transaction_isolation;

SHOW max_connections;

SELECT COUNT(*) AS current_connections
FROM pg_stat_activity;

\echo === Race test fixture safety ===

DO $guard$

DECLARE
    v_base_pid integer;
    v_fixture_ids integer[];

BEGIN

    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect test database';
    END IF;

    IF to_regprocedure(
        'public.place_order(bigint,bigint,integer)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Required function missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.products
        WHERE product_name LIKE 'RACE TEST FIXTURE%'
    ) THEN
        RAISE EXCEPTION
            'Existing race fixtures require investigation';
    END IF;

    SELECT MAX(product_id) + 1000
    INTO v_base_pid
    FROM public.products;

    SELECT array_agg(pid ORDER BY pid)
    INTO v_fixture_ids
    FROM (
        SELECT generate_series(
            v_base_pid,
            v_base_pid + 24
        ) AS pid

        UNION ALL

        SELECT v_base_pid + 100

        UNION ALL

        SELECT v_base_pid + 200

        UNION ALL

        SELECT v_base_pid + 300
    ) AS fixture_ids;

    IF EXISTS (
        SELECT 1
        FROM public.inventory_log
        WHERE product_id = ANY(v_fixture_ids)
    ) THEN
        RAISE EXCEPTION
            'Race fixture IDs overlap historical inventory references';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.order_items
        WHERE product_id = ANY(v_fixture_ids)
    ) THEN
        RAISE EXCEPTION
            'Race fixture IDs overlap historical order items';
    END IF;

    RAISE NOTICE
        'PASS: No existing race fixtures';

    RAISE NOTICE
        'PASS: No historical reference collisions';

    RAISE NOTICE
        'Race fixture IDs: %',
        v_fixture_ids;

    RAISE NOTICE
        'RESULT: Race fixture safety checks passed';

END;

$guard$;

ROLLBACK;