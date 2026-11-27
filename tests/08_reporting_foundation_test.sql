-- DE-03: Kloud Kart
-- Stage 04.2: Reporting foundation verification
--
-- Baseline-specific regression tests.
-- Execute against the original graded dataset
-- after transaction fixture cleanup.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. Status normalization reconciliation ===

SELECT
    normalized_status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS recorded_value

FROM public.v_orders_normalized

GROUP BY normalized_status

ORDER BY normalized_status;


\echo === 2. Raw-to-normalized status mapping ===

SELECT
    QUOTE_NULLABLE(raw_status) AS raw_status,
    normalized_status,
    COUNT(*) AS order_count

FROM public.v_orders_normalized

GROUP BY raw_status, normalized_status

ORDER BY normalized_status, raw_status;


\echo === 3. Unrestricted eligibility ===

SELECT
    COUNT(*) AS eligible_orders,
    COUNT(DISTINCT order_id) AS distinct_orders,
    SUM(total_amount) AS recorded_value

FROM public.v_eligible_orders;


\echo === 4. As-of reporting reconciliation ===

WITH reporting_dates AS (

    SELECT DATE '2026-08-31' AS as_of_date

    UNION ALL

    SELECT DATE '2026-11-26'

)

SELECT
    d.as_of_date,

    COUNT(e.order_id) AS eligible_orders,

    COALESCE(SUM(e.total_amount), 0)
        AS eligible_value,

    COUNT(c.customer_id)
        AS attributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE c.customer_id IS NOT NULL
        ), 0
    ) AS attributed_value,

    COUNT(e.order_id) FILTER (
        WHERE c.customer_id IS NULL
    ) AS unattributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE c.customer_id IS NULL
        ), 0
    ) AS unattributed_value,

    COUNT(DISTINCT c.customer_id)
        AS customers_with_eligible_orders

FROM reporting_dates d

LEFT JOIN LATERAL
    public.eligible_orders_as_of(d.as_of_date) e
    ON TRUE

LEFT JOIN public.customers c
    ON c.customer_id = e.customer_id

GROUP BY d.as_of_date

ORDER BY d.as_of_date;


\echo === 5. Reporting date exception reconciliation ===

WITH reporting_dates AS (

    SELECT DATE '2026-08-31' AS as_of_date

    UNION ALL

    SELECT DATE '2026-11-26'

)

SELECT
    d.as_of_date,

    COUNT(x.order_id) AS excluded_orders,

    COUNT(x.order_id) FILTER (
        WHERE x.status_eligible
    ) AS excluded_eligible_orders,

    COALESCE(
        SUM(x.total_amount) FILTER (
            WHERE x.status_eligible
        ), 0
    ) AS excluded_eligible_value

FROM reporting_dates d

LEFT JOIN LATERAL
    public.reporting_date_exceptions(d.as_of_date) x
    ON TRUE

GROUP BY d.as_of_date

ORDER BY d.as_of_date;


\echo === 6. Dynamic future-dated order view ===

SELECT
    CURRENT_DATE AS observation_date,

    COUNT(*) AS future_orders,

    COUNT(*) FILTER (
        WHERE status_eligible
    ) AS eligible_future_orders,

    COALESCE(
        SUM(total_amount) FILTER (
            WHERE status_eligible
        ), 0
    ) AS eligible_future_value

FROM public.v_future_dated_orders;


\echo === 7. Automated reporting assertions ===

DO $test$

DECLARE
    v_count bigint;
    v_value numeric;
    v_attributed_count bigint;
    v_attributed_value numeric;
    v_unattributed_count bigint;
    v_unattributed_value numeric;
    v_expected record;

BEGIN

    -- R01: Normalization preserves all orders.

    IF (
        SELECT COUNT(*)
        FROM public.v_orders_normalized
    ) <> 159384 THEN
        RAISE EXCEPTION 'R01: Normalized count mismatch';
    END IF;

    RAISE NOTICE 'PASS R01: All 159384 orders preserved';


    -- R02: Normalization does not duplicate orders.

    IF (
        SELECT COUNT(DISTINCT order_id)
        FROM public.v_orders_normalized
    ) <> 159384 THEN
        RAISE EXCEPTION 'R02: Duplicate normalized orders';
    END IF;

    RAISE NOTICE 'PASS R02: One row per order';


    -- R03: Original fields remain unchanged.

    IF EXISTS (

        SELECT
            order_id,
            customer_id,
            order_date,
            status,
            total_amount
        FROM public.orders

        EXCEPT ALL

        SELECT
            order_id,
            customer_id,
            order_date,
            raw_status,
            total_amount
        FROM public.v_orders_normalized

    ) THEN
        RAISE EXCEPTION 'R03: Original fields differ';
    END IF;

    RAISE NOTICE 'PASS R03: Original fields preserved';


    -- R04: Verify all normalized status counts.

    IF EXISTS (

        WITH expected AS (

            SELECT *
            FROM (VALUES
                ('completed', 111351::bigint),
                ('pending',    16009::bigint),
                ('shipped',    12848::bigint),
                ('cancelled',  12697::bigint),
                ('refunded',    6479::bigint)
            ) AS s(status_name, expected_count)

        ),

        actual AS (

            SELECT
                normalized_status,
                COUNT(*) AS actual_count
            FROM public.v_orders_normalized
            GROUP BY normalized_status

        )

        SELECT 1

        FROM expected e

        FULL JOIN actual a
            ON a.normalized_status = e.status_name

        WHERE e.expected_count
            IS DISTINCT FROM a.actual_count

    ) THEN
        RAISE EXCEPTION 'R04: Status distribution mismatch';
    END IF;

    RAISE NOTICE 'PASS R04: Status distribution reconciles';


    -- R05: Unrestricted eligible count and value.

    SELECT COUNT(*), SUM(total_amount)

    INTO v_count, v_value

    FROM public.v_eligible_orders;

    IF v_count <> 111351
       OR v_value IS DISTINCT FROM 339609366.03
    THEN
        RAISE EXCEPTION 'R05: Eligibility mismatch';
    END IF;

    RAISE NOTICE 'PASS R05: Eligible count and value';


    -- R06: Compare eligible order IDs independently
    -- against the original status allowlist.

    IF EXISTS (

        SELECT order_id
        FROM public.orders
        WHERE LOWER(BTRIM(status)) IN (
            'completed', 'complete'
        )

        EXCEPT ALL

        SELECT order_id
        FROM public.v_eligible_orders

    ) OR EXISTS (

        SELECT order_id
        FROM public.v_eligible_orders

        EXCEPT ALL

        SELECT order_id
        FROM public.orders
        WHERE LOWER(BTRIM(status)) IN (
            'completed', 'complete'
        )

    ) THEN
        RAISE EXCEPTION 'R06: Eligible order IDs differ';
    END IF;

    RAISE NOTICE 'PASS R06: Exact eligible order membership';


    -- R07 and R08:
    -- Verify both accepted reporting dates.

    FOR v_expected IN

        SELECT *
        FROM (VALUES

            (
                DATE '2026-08-31',
                111334::bigint,
                339565617.77::numeric,
                111190::bigint,
                339176836.88::numeric
            ),

            (
                DATE '2026-11-26',
                111339::bigint,
                339573765.42::numeric,
                111195::bigint,
                339184984.53::numeric
            )

        ) AS e(
            as_of_date,
            expected_count,
            expected_value,
            expected_attributed_count,
            expected_attributed_value
        )

    LOOP

        SELECT
            COUNT(*),
            SUM(o.total_amount),

            COUNT(c.customer_id),

            SUM(o.total_amount) FILTER (
                WHERE c.customer_id IS NOT NULL
            ),

            COUNT(*) FILTER (
                WHERE c.customer_id IS NULL
            ),

            SUM(o.total_amount) FILTER (
                WHERE c.customer_id IS NULL
            )

        INTO
            v_count,
            v_value,
            v_attributed_count,
            v_attributed_value,
            v_unattributed_count,
            v_unattributed_value

        FROM public.eligible_orders_as_of(
            v_expected.as_of_date
        ) o

        LEFT JOIN public.customers c
            ON c.customer_id = o.customer_id;


        IF v_count <> v_expected.expected_count

           OR v_value IS DISTINCT FROM
                v_expected.expected_value

           OR v_attributed_count <>
                v_expected.expected_attributed_count

           OR v_attributed_value IS DISTINCT FROM
                v_expected.expected_attributed_value

           OR v_unattributed_count <> 144

           OR v_unattributed_value
                IS DISTINCT FROM 388780.89

        THEN

            RAISE EXCEPTION
                'As-of reconciliation failed for %',
                v_expected.as_of_date;

        END IF;


        IF v_count <>
            v_attributed_count + v_unattributed_count

           OR v_value IS DISTINCT FROM
                v_attributed_value + v_unattributed_value

        THEN

            RAISE EXCEPTION
                'Attribution partition failed for %',
                v_expected.as_of_date;

        END IF;


        RAISE NOTICE
            'PASS R07: As-of totals for %',
            v_expected.as_of_date;


        -- Verify exact membership against base data.

        IF EXISTS (

            SELECT order_id

            FROM public.orders

            WHERE LOWER(BTRIM(status)) IN (
                'completed', 'complete'
            )

            AND order_date <
                v_expected.as_of_date + INTERVAL '1 day'

            EXCEPT ALL

            SELECT order_id

            FROM public.eligible_orders_as_of(
                v_expected.as_of_date
            )

        ) OR EXISTS (

            SELECT order_id

            FROM public.eligible_orders_as_of(
                v_expected.as_of_date
            )

            EXCEPT ALL

            SELECT order_id

            FROM public.orders

            WHERE LOWER(BTRIM(status)) IN (
                'completed', 'complete'
            )

            AND order_date <
                v_expected.as_of_date + INTERVAL '1 day'

        ) THEN

            RAISE EXCEPTION
                'As-of order membership failed for %',
                v_expected.as_of_date;

        END IF;

        RAISE NOTICE
            'PASS R08: Exact as-of membership for %',
            v_expected.as_of_date;

    END LOOP;


    -- R09: Exception counts and eligible values.

    FOR v_expected IN

        SELECT *
        FROM (VALUES

            (
                DATE '2026-08-31',
                24::bigint,
                17::bigint,
                43748.26::numeric
            ),

            (
                DATE '2026-11-26',
                15::bigint,
                12::bigint,
                35600.61::numeric
            )

        ) AS e(
            as_of_date,
            expected_count,
            expected_eligible_count,
            expected_eligible_value
        )

    LOOP

        SELECT
            COUNT(*),

            COUNT(*) FILTER (
                WHERE status_eligible
            ),

            SUM(total_amount) FILTER (
                WHERE status_eligible
            )

        INTO
            v_count,
            v_attributed_count,
            v_value

        FROM public.reporting_date_exceptions(
            v_expected.as_of_date
        );


        IF v_count <> v_expected.expected_count

           OR v_attributed_count <>
                v_expected.expected_eligible_count

           OR v_value IS DISTINCT FROM
                v_expected.expected_eligible_value

        THEN

            RAISE EXCEPTION
                'Date exception mismatch for %',
                v_expected.as_of_date;

        END IF;


        -- Included and excluded eligible orders
        -- must reconcile to unrestricted eligibility.

        SELECT COUNT(*), SUM(total_amount)

        INTO v_count, v_attributed_value

        FROM public.eligible_orders_as_of(
            v_expected.as_of_date
        );


        IF v_count + v_attributed_count <> 111351

           OR v_attributed_value + v_value
                IS DISTINCT FROM 339609366.03

        THEN

            RAISE EXCEPTION
                'Eligibility partition mismatch for %',
                v_expected.as_of_date;

        END IF;


        RAISE NOTICE
            'PASS R09: Date exception reconciliation for %',
            v_expected.as_of_date;

    END LOOP;


    -- R10: A date before the dataset returns no orders.

    IF EXISTS (

        SELECT 1

        FROM public.eligible_orders_as_of(
            DATE '2025-01-01'
        )

    ) THEN
        RAISE EXCEPTION 'R10: Unexpected earlier orders';
    END IF;

    RAISE NOTICE 'PASS R10: Empty historical period';


    -- R11: A date beyond all recorded orders
    -- returns unrestricted eligibility.

    SELECT COUNT(*), SUM(total_amount)

    INTO v_count, v_value

    FROM public.eligible_orders_as_of(
        DATE '2027-12-31'
    );

    IF v_count <> 111351
       OR v_value IS DISTINCT FROM 339609366.03
    THEN
        RAISE EXCEPTION 'R11: Full coverage mismatch';
    END IF;

    RAISE NOTICE 'PASS R11: Full historical coverage';


    -- R12: NULL date does not return unrestricted data.

    IF EXISTS (

        SELECT 1

        FROM public.eligible_orders_as_of(NULL::date)

    ) OR EXISTS (

        SELECT 1

        FROM public.reporting_date_exceptions(NULL::date)

    ) THEN
        RAISE EXCEPTION 'R12: NULL date handling failed';
    END IF;

    RAISE NOTICE 'PASS R12: NULL date returns no rows';


    -- R13: Dynamic future view matches original orders.

    IF EXISTS (

        SELECT order_id

        FROM public.orders

        WHERE order_date >=
            CURRENT_DATE + INTERVAL '1 day'

        EXCEPT ALL

        SELECT order_id

        FROM public.v_future_dated_orders

    ) OR EXISTS (

        SELECT order_id

        FROM public.v_future_dated_orders

        EXCEPT ALL

        SELECT order_id

        FROM public.orders

        WHERE order_date >=
            CURRENT_DATE + INTERVAL '1 day'

    ) THEN
        RAISE EXCEPTION 'R13: Future-date view mismatch';
    END IF;

    RAISE NOTICE 'PASS R13: Dynamic future-date membership';


    -- R14: Historical table counts remain unchanged.

    IF (SELECT COUNT(*) FROM public.categories) <> 94

       OR (SELECT COUNT(*) FROM public.customers) <> 40420

       OR (SELECT COUNT(*) FROM public.products) <> 4023

       OR (SELECT COUNT(*) FROM public.orders) <> 159384

       OR (SELECT COUNT(*) FROM public.order_items) <> 336559

       OR (SELECT COUNT(*) FROM public.inventory_log) <> 282352

    THEN
        RAISE EXCEPTION 'R14: Historical baseline mismatch';
    END IF;

    RAISE NOTICE 'PASS R14: Historical baseline reconciles';


    RAISE NOTICE
        'RESULT: All 14 reporting foundation check groups passed';

END;

$test$;


ROLLBACK;