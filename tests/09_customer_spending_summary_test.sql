-- DE-03: Kloud Kart
-- Stage 04.3: Customer spending summary verification
--
-- Baseline-specific regression tests.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect reporting database';
    END IF;
END;
$guard$;


\echo === 1. Customer summary reconciliation ===

WITH reporting_dates AS (

    SELECT DATE '2026-08-31' AS as_of_date

    UNION ALL

    SELECT DATE '2026-11-26'

)

SELECT
    d.as_of_date,

    COUNT(s.customer_id) AS customer_rows,

    COUNT(DISTINCT s.customer_id)
        AS distinct_customers,

    SUM(s.total_spent) AS total_spent,

    SUM(s.order_count) AS total_orders,

    COUNT(*) FILTER (
        WHERE s.order_count > 0
    ) AS customers_with_orders,

    COUNT(*) FILTER (
        WHERE s.order_count = 0
    ) AS customers_without_orders

FROM reporting_dates d

CROSS JOIN LATERAL
    public.customer_spending_summary(d.as_of_date) s

GROUP BY d.as_of_date

ORDER BY d.as_of_date;


\echo === 2. Financial attribution reconciliation ===

SELECT *
FROM public.spending_reconciliation(
    DATE '2026-08-31'
)

UNION ALL

SELECT *
FROM public.spending_reconciliation(
    DATE '2026-11-26'
)

ORDER BY as_of_date;


\echo === 3. Sample customers with eligible orders ===

SELECT
    customer_id,
    total_spent,
    order_count,
    first_order_date,
    last_order_date

FROM public.customer_spending_summary(
    DATE '2026-08-31'
)

WHERE order_count > 0

ORDER BY customer_id

LIMIT 10;


\echo === 4. Sample customers without eligible orders ===

SELECT
    customer_id,
    total_spent,
    order_count,
    first_order_date,
    last_order_date

FROM public.customer_spending_summary(
    DATE '2026-08-31'
)

WHERE order_count = 0

ORDER BY customer_id

LIMIT 10;


\echo === 5. Historical customer population observation ===

SELECT
    COUNT(*) AS current_customer_population,

    COUNT(*) FILTER (
        WHERE registered_at >=
            DATE '2026-08-31' + INTERVAL '1 day'
    ) AS registered_after_headline_date,

    COUNT(*) FILTER (
        WHERE registered_at IS NULL
    ) AS missing_registration_dates

FROM public.customers;


\echo === 6. Automated customer summary assertions ===

DO $test$

DECLARE
    v_expected record;
    v_actual record;
    v_reconciliation record;

BEGIN

    FOR v_expected IN

        SELECT *
        FROM (VALUES

            (
                DATE '2026-08-31',
                111190::bigint,
                339176836.88::numeric,
                111334::bigint,
                339565617.77::numeric
            ),

            (
                DATE '2026-11-26',
                111195::bigint,
                339184984.53::numeric,
                111339::bigint,
                339573765.42::numeric
            )

        ) AS e(
            report_date,
            attributed_orders,
            attributed_value,
            eligible_orders,
            eligible_value
        )

    LOOP

        SELECT

            COUNT(*) AS customer_rows,

            COUNT(DISTINCT s.customer_id)
                AS distinct_customers,

            SUM(s.total_spent) AS total_spent,

            SUM(s.order_count) AS total_orders,

            COUNT(*) FILTER (
                WHERE s.order_count > 0
            ) AS active_customers,

            COUNT(*) FILTER (
                WHERE s.order_count = 0
            ) AS inactive_customers

        INTO v_actual

        FROM public.customer_spending_summary(
            v_expected.report_date
        ) s;


        -- S01: Exactly one row per customer.

        IF v_actual.customer_rows <> 40420

           OR v_actual.distinct_customers <> 40420

        THEN
            RAISE EXCEPTION
                'S01: Customer coverage failed for %',
                v_expected.report_date;
        END IF;

        RAISE NOTICE
            'PASS S01: Customer coverage for %',
            v_expected.report_date;


        -- S02: Aggregate spending and order counts.

        IF v_actual.total_spent IS DISTINCT FROM
            v_expected.attributed_value

           OR v_actual.total_orders IS DISTINCT FROM
            v_expected.attributed_orders

        THEN
            RAISE EXCEPTION
                'S02: Spending totals failed for %',
                v_expected.report_date;
        END IF;

        RAISE NOTICE
            'PASS S02: Spending totals for %',
            v_expected.report_date;


        -- S03: Customers with and without orders.

        IF v_actual.active_customers <> 37900

           OR v_actual.inactive_customers <> 2520

        THEN
            RAISE EXCEPTION
                'S03: Customer activity coverage failed';
        END IF;

        RAISE NOTICE
            'PASS S03: Customer activity coverage for %',
            v_expected.report_date;


        -- S04: Validate zero-order customer records.

        IF EXISTS (

            SELECT 1

            FROM public.customer_spending_summary(
                v_expected.report_date
            ) s

            WHERE s.order_count = 0

              AND (
                  s.total_spent IS DISTINCT FROM 0

                  OR s.first_order_date IS NOT NULL

                  OR s.last_order_date IS NOT NULL
              )

        ) THEN
            RAISE EXCEPTION
                'S04: Invalid zero-order customer';
        END IF;

        RAISE NOTICE
            'PASS S04: Zero-order customers for %',
            v_expected.report_date;


        -- S05: Validate active customer date ranges.

        IF EXISTS (

            SELECT 1

            FROM public.customer_spending_summary(
                v_expected.report_date
            ) s

            WHERE s.order_count > 0

              AND (

                  s.first_order_date IS NULL

                  OR s.last_order_date IS NULL

                  OR s.first_order_date >
                     s.last_order_date

                  OR s.last_order_date >=
                     v_expected.report_date
                     + INTERVAL '1 day'

              )

        ) THEN
            RAISE EXCEPTION
                'S05: Invalid customer order dates';
        END IF;

        RAISE NOTICE
            'PASS S05: Customer date ranges for %',
            v_expected.report_date;


        -- S06: Independently verify every customer
        -- against original orders and customers.

        IF EXISTS (

            WITH expected AS (

                SELECT
                    c.customer_id,
                    c.full_name,

                    COALESCE(SUM(o.total_amount), 0)
                        AS total_spent,

                    COUNT(o.order_id)
                        AS order_count,

                    MIN(o.order_date)
                        AS first_order_date,

                    MAX(o.order_date)
                        AS last_order_date

                FROM public.customers c

                LEFT JOIN public.orders o

                    ON o.customer_id = c.customer_id

                   AND LOWER(BTRIM(o.status)) IN (
                       'completed', 'complete'
                   )

                   AND o.order_date <
                       v_expected.report_date
                       + INTERVAL '1 day'

                GROUP BY
                    c.customer_id,
                    c.full_name

            ),

            actual AS (

                SELECT *

                FROM public.customer_spending_summary(
                    v_expected.report_date
                )

            )

            SELECT 1

            FROM expected e

            FULL JOIN actual a
                ON a.customer_id = e.customer_id

            WHERE e.customer_id IS NULL

               OR a.customer_id IS NULL

               OR a.as_of_date IS DISTINCT FROM
                  v_expected.report_date

               OR a.full_name IS DISTINCT FROM
                  e.full_name

               OR a.total_spent IS DISTINCT FROM
                  e.total_spent

               OR a.order_count IS DISTINCT FROM
                  e.order_count

               OR a.first_order_date IS DISTINCT FROM
                  e.first_order_date

               OR a.last_order_date IS DISTINCT FROM
                  e.last_order_date

        ) THEN
            RAISE EXCEPTION
                'S06: Individual customer mismatch for %',
                v_expected.report_date;
        END IF;

        RAISE NOTICE
            'PASS S06: All customer records verified for %',
            v_expected.report_date;


        -- S07: Financial reconciliation.

        SELECT *

        INTO STRICT v_reconciliation

        FROM public.spending_reconciliation(
            v_expected.report_date
        );


        IF v_reconciliation.as_of_date IS DISTINCT FROM
            v_expected.report_date

           OR v_reconciliation.eligible_orders
                IS DISTINCT FROM
                v_expected.eligible_orders

           OR v_reconciliation.eligible_value
                IS DISTINCT FROM
                v_expected.eligible_value

           OR v_reconciliation.attributed_orders
                IS DISTINCT FROM
                v_expected.attributed_orders

           OR v_reconciliation.attributed_value
                IS DISTINCT FROM
                v_expected.attributed_value

           OR v_reconciliation.unattributed_orders
                IS DISTINCT FROM 144

           OR v_reconciliation.unattributed_value
                IS DISTINCT FROM 388780.89

        THEN
            RAISE EXCEPTION
                'S07: Financial reconciliation failed';
        END IF;

        RAISE NOTICE
            'PASS S07: Financial reconciliation for %',
            v_expected.report_date;


        -- S08: Attributed and unattributed partitions.

        IF v_reconciliation.eligible_orders
                IS DISTINCT FROM (
                    v_reconciliation.attributed_orders
                    + v_reconciliation.unattributed_orders
                )

           OR v_reconciliation.eligible_value
                IS DISTINCT FROM (
                    v_reconciliation.attributed_value
                    + v_reconciliation.unattributed_value
                )

           OR v_actual.total_spent IS DISTINCT FROM
                v_reconciliation.attributed_value

           OR v_actual.total_orders IS DISTINCT FROM
                v_reconciliation.attributed_orders

        THEN
            RAISE EXCEPTION
                'S08: Financial partition mismatch';
        END IF;

        RAISE NOTICE
            'PASS S08: Financial partition for %',
            v_expected.report_date;

    END LOOP;


    -- S09: Date before all recorded orders.

    IF (

        SELECT COUNT(*)

        FROM public.customer_spending_summary(
            DATE '2025-01-01'
        )

    ) <> 40420

    OR EXISTS (

        SELECT 1

        FROM public.customer_spending_summary(
            DATE '2025-01-01'
        ) s

        WHERE s.total_spent IS DISTINCT FROM 0

           OR s.order_count IS DISTINCT FROM 0

           OR s.first_order_date IS NOT NULL

           OR s.last_order_date IS NOT NULL

    ) THEN
        RAISE EXCEPTION
            'S09: Empty spending period failed';
    END IF;

    RAISE NOTICE
        'PASS S09: Empty spending period';


    -- S10: Empty financial reconciliation.

    SELECT *

    INTO STRICT v_reconciliation

    FROM public.spending_reconciliation(
        DATE '2025-01-01'
    );

    IF v_reconciliation.eligible_orders
            IS DISTINCT FROM 0

       OR v_reconciliation.eligible_value
            IS DISTINCT FROM 0

       OR v_reconciliation.attributed_orders
            IS DISTINCT FROM 0

       OR v_reconciliation.attributed_value
            IS DISTINCT FROM 0

       OR v_reconciliation.unattributed_orders
            IS DISTINCT FROM 0

       OR v_reconciliation.unattributed_value
            IS DISTINCT FROM 0

    THEN
        RAISE EXCEPTION
            'S10: Empty reconciliation failed';
    END IF;

    RAISE NOTICE
        'PASS S10: Empty financial reconciliation';


    -- S11: NULL date contract.

    IF EXISTS (

        SELECT 1

        FROM public.customer_spending_summary(
            NULL::date
        )

    ) OR EXISTS (

        SELECT 1

        FROM public.spending_reconciliation(
            NULL::date
        )

    ) THEN
        RAISE EXCEPTION
            'S11: NULL date handling failed';
    END IF;

    RAISE NOTICE
        'PASS S11: NULL date handling';


    -- S12: Historical baseline reconciliation.

    IF (SELECT COUNT(*) FROM public.categories) <> 94

       OR (SELECT COUNT(*) FROM public.customers) <> 40420

       OR (SELECT COUNT(*) FROM public.products) <> 4023

       OR (SELECT COUNT(*) FROM public.orders) <> 159384

       OR (SELECT COUNT(*) FROM public.order_items) <> 336559

       OR (SELECT COUNT(*) FROM public.inventory_log) <> 282352

    THEN
        RAISE EXCEPTION
            'S12: Historical baseline mismatch';
    END IF;

    RAISE NOTICE
        'PASS S12: Historical baseline reconciles';


    RAISE NOTICE
        'RESULT: All 12 customer summary check groups passed';

END;

$test$;


ROLLBACK;