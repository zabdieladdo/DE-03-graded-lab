
-- DE-03: Kloud Kart
-- Stage 04.5: Running spending verification
-- Decision: D030
-- Evidence: E043
--
-- Independent raw-order calculations.
-- Duplicate-sensitive comparisons.
-- Read-only verification.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_running_verification';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


DO $test$

DECLARE
    v_expected record;
    v_actual record;
    v_start date;
    v_month date;

BEGIN

    FOR v_expected IN

        SELECT *
        FROM (
            VALUES

            (
                DATE '2026-08-31',
                111190::bigint,
                1488::bigint,
                109702::bigint,
                4542077.88::numeric,
                334634759.00::numeric,
                339176836.88::numeric,
                84::bigint
            ),

            (
                DATE '2026-11-26',
                111195::bigint,
                8732::bigint,
                102463::bigint,
                26170939.50::numeric,
                313014045.03::numeric,
                339184984.53::numeric,
                615::bigint
            )

        ) d(
            report_date,
            attributed_orders,
            opening_orders,
            window_orders,
            opening_spending,
            window_spending,
            history_spending,
            opening_only_customers
        )

    LOOP

        v_month := DATE_TRUNC(
            'month',
            v_expected.report_date::timestamp
        )::date;

        v_start := (
            v_month - INTERVAL '11 months'
        )::date;

        RAISE NOTICE
            'Starting checks for %',
            v_expected.report_date;


        -- C01: Monthly population and uniqueness

        RAISE NOTICE 'RUN C01: Monthly coverage';

        SELECT
            COUNT(*) AS report_rows,
            COUNT(DISTINCT customer_id) AS customers,
            COUNT(DISTINCT order_month) AS months,
            COUNT(
                DISTINCT (customer_id, order_month)
            ) AS unique_pairs

        INTO v_actual

        FROM public.customer_monthly_running_spending(
            v_expected.report_date
        );

        IF v_actual.report_rows <> 485040
           OR v_actual.customers <> 40420
           OR v_actual.months <> 12
           OR v_actual.unique_pairs <> 485040

        THEN
            RAISE EXCEPTION
                'C01: Monthly coverage mismatch';
        END IF;

        RAISE NOTICE
            'PASS C01: Monthly coverage for %',
            v_expected.report_date;


        -- C02: Independently construct every monthly record

        RAISE NOTICE
            'RUN C02: Monthly multiset comparison';

        IF EXISTS (

            WITH raw_eligible AS MATERIALIZED (

                SELECT
                    o.customer_id,
                    o.order_date,
                    o.total_amount

                FROM public.orders o

                JOIN public.customers c
                    ON c.customer_id = o.customer_id

                WHERE LOWER(BTRIM(o.status))
                    IN ('completed', 'complete')

                  AND o.order_date <
                    v_expected.report_date
                    + INTERVAL '1 day'

            ),

            opening AS (

                SELECT
                    customer_id,
                    SUM(total_amount) AS amount

                FROM raw_eligible

                WHERE order_date < v_start

                GROUP BY customer_id

            ),

            contributions AS (

                -- Zero-valued customer-month grid

                SELECT
                    c.customer_id,

                    (
                        v_start
                        + n.month_offset
                          * INTERVAL '1 month'
                    )::date AS order_month,

                    0::numeric AS amount,
                    0::bigint AS orders

                FROM public.customers c

                CROSS JOIN GENERATE_SERIES(
                    0, 11
                ) AS n(month_offset)

                UNION ALL

                -- Independently aggregated activity

                SELECT
                    customer_id,

                    DATE_TRUNC(
                        'month', order_date
                    )::date,

                    SUM(total_amount),
                    COUNT(*)

                FROM raw_eligible

                WHERE order_date >= v_start

                GROUP BY
                    customer_id,
                    DATE_TRUNC(
                        'month', order_date
                    )::date

            ),

            monthly AS (

                SELECT
                    customer_id,
                    order_month,
                    SUM(amount) AS spending,
                    SUM(orders)::bigint AS order_count

                FROM contributions

                GROUP BY
                    customer_id,
                    order_month

            ),

            running AS (

                SELECT
                    m.*,

                    SUM(m.spending) OVER (

                        PARTITION BY m.customer_id

                        ORDER BY m.order_month

                        ROWS BETWEEN
                            UNBOUNDED PRECEDING
                            AND CURRENT ROW

                    ) AS cumulative

                FROM monthly m

            ),

            expected AS MATERIALIZED (

                SELECT
                    v_expected.report_date
                        AS as_of_date,

                    r.customer_id,
                    r.order_month,
                    r.spending,
                    r.order_count,

                    COALESCE(
                        o.amount, 0::numeric
                    ) AS opening_spending,

                    r.cumulative,

                    COALESCE(
                        o.amount, 0::numeric
                    ) + r.cumulative,

                    (
                        r.order_month = v_month

                        AND EXTRACT(
                            DAY FROM
                            v_expected.report_date + 1
                        ) <> 1
                    ) AS is_partial_month

                FROM running r

                LEFT JOIN opening o
                    ON o.customer_id = r.customer_id

            ),

            actual AS MATERIALIZED (

                SELECT *

                FROM
                    public.customer_monthly_running_spending(
                        v_expected.report_date
                    )

            )

            (
                SELECT * FROM expected

                EXCEPT ALL

                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual

                EXCEPT ALL

                SELECT * FROM expected
            )

        ) THEN

            RAISE EXCEPTION
                'C02: Monthly record mismatch';

        END IF;

        RAISE NOTICE
            'PASS C02: All monthly records for %',
            v_expected.report_date;


        -- C03: Transaction population and uniqueness

        RAISE NOTICE
            'RUN C03: Transaction coverage';

        SELECT
            COUNT(*) AS report_rows,
            COUNT(DISTINCT order_id) AS unique_orders,
            COUNT(DISTINCT customer_id) AS customers

        INTO v_actual

        FROM public.customer_order_running_spending(
            v_expected.report_date
        );

        IF v_actual.report_rows <>
                v_expected.attributed_orders

           OR v_actual.unique_orders <>
                v_expected.attributed_orders

           OR v_actual.customers <> 37900

        THEN
            RAISE EXCEPTION
                'C03: Transaction coverage mismatch';
        END IF;

        RAISE NOTICE
            'PASS C03: Transaction coverage for %',
            v_expected.report_date;


        -- C04: Independent transaction calculation
        --
        -- Alternative calculation:
        -- calculate cumulative recorded history,
        -- then subtract the customer's opening balance.

        RAISE NOTICE
            'RUN C04: Transaction multiset comparison';

        IF EXISTS (

            WITH raw_eligible AS (

                SELECT
                    o.customer_id,
                    o.order_id,
                    o.order_date,
                    o.total_amount

                FROM public.orders o

                JOIN public.customers c
                    ON c.customer_id = o.customer_id

                WHERE LOWER(BTRIM(o.status))
                    IN ('completed', 'complete')

                  AND o.order_date <
                    v_expected.report_date
                    + INTERVAL '1 day'

            ),

            calculated AS (

                SELECT
                    e.*,

                    SUM(e.total_amount) OVER (

                        PARTITION BY e.customer_id

                        ORDER BY
                            e.order_date,
                            e.order_id

                        ROWS BETWEEN
                            UNBOUNDED PRECEDING
                            AND CURRENT ROW

                    ) AS history_total,

                    COALESCE(

                        SUM(
                            CASE
                                WHEN e.order_date < v_start
                                THEN e.total_amount
                                ELSE 0::numeric
                            END
                        ) OVER (
                            PARTITION BY e.customer_id
                        ),

                        0::numeric

                    ) AS opening_total

                FROM raw_eligible e

            ),

            expected AS MATERIALIZED (

                SELECT
                    v_expected.report_date,
                    customer_id,
                    order_id,
                    order_date,
                    total_amount,

                    order_date >= v_start,

                    CASE

                        WHEN order_date >= v_start

                        THEN history_total
                             - opening_total

                        ELSE NULL::numeric

                    END,

                    history_total

                FROM calculated

            ),

            actual AS MATERIALIZED (

                SELECT *

                FROM
                    public.customer_order_running_spending(
                        v_expected.report_date
                    )

            )

            (
                SELECT * FROM expected

                EXCEPT ALL

                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual

                EXCEPT ALL

                SELECT * FROM expected
            )

        ) THEN

            RAISE EXCEPTION
                'C04: Transaction record mismatch';

        END IF;

        RAISE NOTICE
            'PASS C04: All transaction records for %',
            v_expected.report_date;


        -- C05: Final monthly financial reconciliation

        RAISE NOTICE
            'RUN C05: Final monthly balances';

        SELECT
            COUNT(*) AS customers,
            SUM(opening_spending) AS opening,
            SUM(window_cumulative_spending) AS spending,
            SUM(cumulative_since_extract_start) AS history

        INTO v_actual

        FROM public.customer_monthly_running_spending(
            v_expected.report_date
        )

        WHERE order_month = v_month;

        IF v_actual.customers <> 40420

           OR v_actual.opening IS DISTINCT FROM
                v_expected.opening_spending

           OR v_actual.spending IS DISTINCT FROM
                v_expected.window_spending

           OR v_actual.history IS DISTINCT FROM
                v_expected.history_spending

        THEN
            RAISE EXCEPTION
                'C05: Final monthly balance mismatch';
        END IF;

        RAISE NOTICE
            'PASS C05: Final monthly balances for %',
            v_expected.report_date;


        -- C06: Transaction financial reconciliation

        RAISE NOTICE
            'RUN C06: Transaction reconciliation';

        SELECT
            COUNT(*) FILTER (
                WHERE NOT is_in_reporting_window
            ) AS opening_orders,

            COUNT(*) FILTER (
                WHERE is_in_reporting_window
            ) AS window_orders,

            SUM(order_amount) FILTER (
                WHERE NOT is_in_reporting_window
            ) AS opening_spending,

            SUM(order_amount) FILTER (
                WHERE is_in_reporting_window
            ) AS window_spending,

            SUM(order_amount) AS history_spending

        INTO v_actual

        FROM public.customer_order_running_spending(
            v_expected.report_date
        );

        IF v_actual.opening_orders <>
                v_expected.opening_orders

           OR v_actual.window_orders <>
                v_expected.window_orders

           OR v_actual.opening_spending
                IS DISTINCT FROM
                v_expected.opening_spending

           OR v_actual.window_spending
                IS DISTINCT FROM
                v_expected.window_spending

           OR v_actual.history_spending
                IS DISTINCT FROM
                v_expected.history_spending

        THEN
            RAISE EXCEPTION
                'C06: Transaction totals mismatch';
        END IF;

        RAISE NOTICE
            'PASS C06: Transaction totals for %',
            v_expected.report_date;


        -- C07: Opening-only customers

        RAISE NOTICE
            'RUN C07: Opening-only customers';

        SELECT COUNT(*) AS customers

        INTO v_actual

        FROM (

            SELECT customer_id

            FROM
                public.customer_monthly_running_spending(
                    v_expected.report_date
                )

            GROUP BY customer_id

            HAVING MAX(opening_spending) > 0

               AND SUM(monthly_order_count) = 0

               AND BOOL_AND(
                   window_cumulative_spending = 0

                   AND cumulative_since_extract_start
                       = opening_spending
               )

        ) q;

        IF v_actual.customers <>
                v_expected.opening_only_customers

        THEN
            RAISE EXCEPTION
                'C07: Opening-only population mismatch';
        END IF;

        RAISE NOTICE
            'PASS C07: Opening-only customers for %',
            v_expected.report_date;


        -- C08: Customers without eligible orders

        RAISE NOTICE
            'RUN C08: Inactive customer coverage';

        SELECT COUNT(*) AS customers

        INTO v_actual

        FROM (

            SELECT customer_id

            FROM
                public.customer_monthly_running_spending(
                    v_expected.report_date
                )

            GROUP BY customer_id

            HAVING SUM(monthly_order_count) = 0

               AND BOOL_AND(
                   opening_spending = 0

                   AND window_cumulative_spending = 0

                   AND cumulative_since_extract_start = 0
               )

        ) q;

        IF v_actual.customers <> 2520 THEN

            RAISE EXCEPTION
                'C08: Inactive customer mismatch';

        END IF;

        RAISE NOTICE
            'PASS C08: Inactive customers for %',
            v_expected.report_date;


        -- C09: Pre-window NULL semantics

        RAISE NOTICE
            'RUN C09: Pre-window NULL semantics';

        IF EXISTS (

            SELECT 1

            FROM
                public.customer_order_running_spending(
                    v_expected.report_date
                )

            WHERE
                (
                    NOT is_in_reporting_window

                    AND window_cumulative_spending
                        IS NOT NULL
                )

                OR

                (
                    is_in_reporting_window

                    AND window_cumulative_spending
                        IS NULL
                )

        ) THEN

            RAISE EXCEPTION
                'C09: Invalid window balance semantics';

        END IF;

        RAISE NOTICE
            'PASS C09: NULL semantics for %',
            v_expected.report_date;

    END LOOP;


    -- C10: Empty historical reporting window

    RAISE NOTICE
        'RUN C10: Empty historical window';

    SELECT
        COUNT(*) AS report_rows,

        COUNT(*) FILTER (

            WHERE monthly_spending
                    IS DISTINCT FROM 0::numeric

               OR monthly_order_count
                    IS DISTINCT FROM 0::bigint

               OR opening_spending
                    IS DISTINCT FROM 0::numeric

               OR window_cumulative_spending
                    IS DISTINCT FROM 0::numeric

               OR cumulative_since_extract_start
                    IS DISTINCT FROM 0::numeric

        ) AS invalid_rows

    INTO v_actual

    FROM public.customer_monthly_running_spending(
        DATE '2025-01-31'
    );

    IF v_actual.report_rows <> 485040

       OR v_actual.invalid_rows <> 0

       OR EXISTS (

           SELECT 1

           FROM
               public.customer_order_running_spending(
                   DATE '2025-01-31'
               )

       )

    THEN
        RAISE EXCEPTION
            'C10: Empty historical window mismatch';
    END IF;

    RAISE NOTICE
        'PASS C10: Empty historical window';


    -- C11: NULL date handling

    RAISE NOTICE
        'RUN C11: NULL date handling';

    IF EXISTS (

        SELECT 1

        FROM public.customer_monthly_running_spending(
            NULL::date
        )

    ) OR EXISTS (

        SELECT 1

        FROM public.customer_order_running_spending(
            NULL::date
        )

    ) THEN

        RAISE EXCEPTION
            'C11: NULL date returned records';

    END IF;

    RAISE NOTICE
        'PASS C11: NULL date handling';


    -- C12: Synthetic timestamp-tie expression test
    --
    -- Tests the ordering and window expression.
    -- Does not insert records into production tables.

    RAISE NOTICE
        'RUN C12: Synthetic timestamp ties';

    IF EXISTS (

        WITH fixture AS (

            SELECT *

            FROM (

                VALUES

                (
                    1, 103,
                    TIMESTAMP '2026-08-01 10:00:00',
                    75::numeric,
                    225::numeric
                ),

                (
                    1, 101,
                    TIMESTAMP '2026-08-01 10:00:00',
                    100::numeric,
                    100::numeric
                ),

                (
                    1, 102,
                    TIMESTAMP '2026-08-01 10:00:00',
                    50::numeric,
                    150::numeric
                ),

                (
                    2, 201,
                    TIMESTAMP '2026-08-01 10:00:00',
                    25::numeric,
                    25::numeric
                )

            ) f(
                customer_id,
                order_id,
                order_date,
                amount,
                expected_total
            )

        ),

        calculated AS (

            SELECT
                *,

                SUM(amount) OVER (

                    PARTITION BY customer_id

                    ORDER BY order_date, order_id

                    ROWS BETWEEN
                        UNBOUNDED PRECEDING
                        AND CURRENT ROW

                ) AS actual_total

            FROM fixture

        )

        SELECT 1

        FROM calculated

        WHERE actual_total
            IS DISTINCT FROM expected_total

    ) THEN

        RAISE EXCEPTION
            'C12: Timestamp-tie calculation mismatch';

    END IF;

    RAISE NOTICE
        'PASS C12: Synthetic timestamp-tie expression';


    -- C13: Historical baseline counts

    RAISE NOTICE
        'RUN C13: Historical baseline counts';

    IF (SELECT COUNT(*) FROM public.categories) <> 94

       OR (SELECT COUNT(*) FROM public.products) <> 4023

       OR (SELECT COUNT(*) FROM public.customers) <> 40420

       OR (SELECT COUNT(*) FROM public.orders) <> 159384

       OR (SELECT COUNT(*) FROM public.order_items) <> 336559

       OR (SELECT COUNT(*) FROM public.inventory_log) <> 282352

    THEN

        RAISE EXCEPTION
            'C13: Historical baseline count mismatch';

    END IF;

    RAISE NOTICE
        'PASS C13: Historical baseline reconciles';

    RAISE NOTICE
        'RESULT: All 13 running spending check groups passed';

END;

$test$;

ROLLBACK;
