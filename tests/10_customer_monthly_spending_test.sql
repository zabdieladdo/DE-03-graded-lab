-- DE-03: Kloud Kart
-- Stage 04.4: Monthly reporting verification (revision 3)
-- M06/M07/M09: duplicate-sensitive bidirectional set comparisons.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_monthly_verification';
SET LOCAL client_min_messages = notice;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. Reporting window metadata ===

SELECT *
FROM public.monthly_reporting_metadata(
    DATE '2026-08-31'
)

UNION ALL

SELECT *
FROM public.monthly_reporting_metadata(
    DATE '2026-11-26'
);


\echo === 2. Dense monthly financial reconciliation ===

WITH reporting_dates AS (

    SELECT DATE '2026-08-31' AS as_of_date

    UNION ALL

    SELECT DATE '2026-11-26'

)

SELECT
    d.as_of_date,

    COUNT(*) AS report_rows,

    COUNT(DISTINCT m.customer_id)
        AS customers,

    COUNT(DISTINCT m.order_month)
        AS reporting_months,

    COUNT(*) FILTER (
        WHERE m.monthly_order_count > 0
    ) AS active_customer_months,

    COUNT(*) FILTER (
        WHERE m.monthly_order_count = 0
    ) AS zero_order_months,

    COUNT(*) FILTER (
        WHERE m.is_partial_month
    ) AS partial_month_rows,

    SUM(m.monthly_order_count)
        AS attributed_orders,

    SUM(m.monthly_spending)
        AS attributed_spending

FROM reporting_dates d

CROSS JOIN LATERAL
    public.customer_monthly_spending(
        d.as_of_date
    ) m

GROUP BY d.as_of_date

ORDER BY d.as_of_date;


\echo === 3. Headline monthly totals ===

SELECT
    order_month,

    SUM(monthly_order_count) AS order_count,

    SUM(monthly_spending) AS spending,

    COUNT(*) FILTER (
        WHERE monthly_order_count > 0
    ) AS purchasing_customers

FROM public.customer_monthly_spending(
    DATE '2026-08-31'
)

GROUP BY order_month

ORDER BY order_month;


\echo === 4. Wide-format sample (generating report; timeout 120 seconds) ===

SELECT *

FROM public.customer_monthly_spending_wide(
    DATE '2026-08-31'
)

ORDER BY customer_id

LIMIT 5;


\echo === 5. Automated monthly reporting assertions ===

DO $test$

DECLARE
    v_expected record;
    v_actual record;
    v_meta record;

BEGIN

    FOR v_expected IN

        SELECT *
        FROM (VALUES

            (
                DATE '2026-08-31',
                DATE '2025-09-01',
                92677::bigint,
                392363::bigint,
                109702::bigint,
                334634759.00::numeric,
                false
            ),

            (
                DATE '2026-11-26',
                DATE '2025-12-01',
                85681::bigint,
                399359::bigint,
                102463::bigint,
                313014045.03::numeric,
                true
            )

        ) AS e(
            report_date,
            window_start,
            active_rows,
            zero_rows,
            order_count,
            spending,
            partial_month
        )

    LOOP
        RAISE NOTICE 'Starting checks for %', v_expected.report_date;

        -- M01: Reporting metadata.
        RAISE NOTICE 'RUN M01: Reporting metadata. %', v_expected.report_date;

        SELECT *
        INTO STRICT v_meta

        FROM public.monthly_reporting_metadata(
            v_expected.report_date
        );

        IF v_meta.as_of_date IS DISTINCT FROM
                v_expected.report_date

           OR v_meta.window_start IS DISTINCT FROM
                v_expected.window_start

           OR v_meta.window_end_exclusive
                IS DISTINCT FROM (
                    v_expected.report_date
                    + INTERVAL '1 day'
                )

           OR v_meta.month_count IS DISTINCT FROM 12

           OR v_meta.is_partial_month IS DISTINCT FROM
                v_expected.partial_month

           OR NULLIF(BTRIM(v_meta.coverage_warning), '')
                IS NULL

        THEN
            RAISE EXCEPTION 'M01: Metadata mismatch';
        END IF;

        RAISE NOTICE 'PASS M01: Metadata for %',
            v_expected.report_date;


        -- M02: Dense output coverage and grain.
        RAISE NOTICE 'RUN M02: Dense output coverage and grain. %', v_expected.report_date;

        SELECT
            COUNT(*) AS report_rows,

            COUNT(DISTINCT m.customer_id)
                AS customers,

            COUNT(DISTINCT m.order_month)
                AS months,

            COUNT(
                DISTINCT (m.customer_id, m.order_month)
            ) AS distinct_pairs,

            COUNT(*) FILTER (
                WHERE m.monthly_order_count > 0
            ) AS active_rows,

            COUNT(*) FILTER (
                WHERE m.monthly_order_count = 0
            ) AS zero_rows,

            COUNT(*) FILTER (
                WHERE m.is_partial_month
            ) AS partial_rows,

            SUM(m.monthly_order_count)
                AS order_count,

            SUM(m.monthly_spending)
                AS spending

        INTO v_actual

        FROM public.customer_monthly_spending(
            v_expected.report_date
        ) m;

        IF v_actual.report_rows <> 485040

           OR v_actual.distinct_pairs <> 485040

           OR v_actual.customers <> 40420

           OR v_actual.months <> 12

        THEN
            RAISE EXCEPTION 'M02: Dense coverage failed';
        END IF;

        RAISE NOTICE 'PASS M02: Dense coverage for %',
            v_expected.report_date;


        -- M03: Active and zero-order months.
        RAISE NOTICE 'RUN M03: Active and zero-order months. %', v_expected.report_date;

        IF v_actual.active_rows IS DISTINCT FROM
                v_expected.active_rows

           OR v_actual.zero_rows IS DISTINCT FROM
                v_expected.zero_rows

        THEN
            RAISE EXCEPTION 'M03: Density mismatch';
        END IF;

        RAISE NOTICE 'PASS M03: Monthly density for %',
            v_expected.report_date;


        -- M04: Financial reconciliation.
        RAISE NOTICE 'RUN M04: Financial reconciliation. %', v_expected.report_date;

        IF v_actual.order_count IS DISTINCT FROM
                v_expected.order_count

           OR v_actual.spending IS DISTINCT FROM
                v_expected.spending

        THEN
            RAISE EXCEPTION 'M04: Financial mismatch';
        END IF;

        RAISE NOTICE 'PASS M04: Financial totals for %',
            v_expected.report_date;


        -- M05: Partial-month coverage.
        RAISE NOTICE 'RUN M05: Partial-month coverage. %', v_expected.report_date;

        IF (v_expected.partial_month AND v_actual.partial_rows IS DISTINCT FROM 40420::bigint)
           OR (NOT v_expected.partial_month AND v_actual.partial_rows IS DISTINCT FROM 0::bigint)
        THEN
            RAISE EXCEPTION 'M05: Partial-month mismatch';
        END IF;

        RAISE NOTICE 'PASS M05: Partial-month coverage for %',
            v_expected.report_date;


        -- M06: Independently verify sparse activity, including duplicates.
        RAISE NOTICE 'RUN M06: Sparse multiset comparison for %', v_expected.report_date;
        IF EXISTS (
            WITH expected AS MATERIALIZED (
                SELECT v_expected.report_date AS as_of_date,
                       o.customer_id,
                       date_trunc('month', o.order_date)::date AS order_month,
                       sum(o.total_amount) AS monthly_spending,
                       count(*) AS monthly_order_count
                FROM public.orders o
                JOIN public.customers c ON c.customer_id = o.customer_id
                WHERE lower(btrim(o.status)) IN ('completed', 'complete')
                  AND o.order_date >= v_expected.window_start
                  AND o.order_date < v_expected.report_date + interval '1 day'
                GROUP BY o.customer_id, date_trunc('month', o.order_date)::date
            ), actual AS MATERIALIZED (
                SELECT as_of_date, customer_id, order_month,
                       monthly_spending, monthly_order_count
                FROM public.customer_monthly_spending_sparse(v_expected.report_date)
            )
            (SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
            UNION ALL
            (SELECT * FROM actual EXCEPT ALL SELECT * FROM expected)
        ) THEN
            RAISE EXCEPTION 'M06: Sparse activity mismatch';
        END IF;
        RAISE NOTICE 'PASS M06: Sparse activity for %', v_expected.report_date;

        -- M07: Verify every dense customer-month pair without a three-way join.
        RAISE NOTICE 'RUN M07: Dense multiset comparison for %', v_expected.report_date;
        IF EXISTS (
            WITH contributions AS (
                -- One zero contribution for each expected customer-month.
                SELECT c.customer_id,
                       (v_expected.window_start + n.month_offset * interval '1 month')::date AS order_month,
                       0::numeric AS spending, 0::bigint AS order_count
                FROM public.customers c
                CROSS JOIN generate_series(0, 11) AS n(month_offset)
                UNION ALL
                -- Independently aggregate the original orders.
                SELECT o.customer_id,
                       date_trunc('month', o.order_date)::date,
                       sum(o.total_amount), count(*)
                FROM public.orders o
                JOIN public.customers c ON c.customer_id = o.customer_id
                WHERE lower(btrim(o.status)) IN ('completed', 'complete')
                  AND o.order_date >= v_expected.window_start
                  AND o.order_date < v_expected.report_date + interval '1 day'
                GROUP BY o.customer_id, date_trunc('month', o.order_date)::date
            ), expected AS MATERIALIZED (
                SELECT v_expected.report_date AS as_of_date,
                       customer_id, order_month,
                       sum(spending) AS monthly_spending,
                       sum(order_count)::bigint AS monthly_order_count,
                       (v_expected.partial_month AND order_month =
                           (v_expected.window_start + interval '11 months')::date) AS is_partial_month
                FROM contributions
                GROUP BY customer_id, order_month
            ), actual AS MATERIALIZED (
                SELECT as_of_date, customer_id, order_month,
                       monthly_spending, monthly_order_count, is_partial_month
                FROM public.customer_monthly_spending(v_expected.report_date)
            )
            (SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
            UNION ALL
            (SELECT * FROM actual EXCEPT ALL SELECT * FROM expected)
        ) THEN
            RAISE EXCEPTION 'M07: Dense record mismatch';
        END IF;
        RAISE NOTICE 'PASS M07: All dense records for %', v_expected.report_date;

        -- M08: Wide-format coverage.
        RAISE NOTICE 'RUN M08: Wide-format coverage. %', v_expected.report_date;

        SELECT COUNT(*) AS report_rows,
               COUNT(DISTINCT customer_id) AS customers
        INTO v_actual
        FROM public.customer_monthly_spending_wide(
            v_expected.report_date
        );

        IF v_actual.report_rows <> 40420
           OR v_actual.customers <> 40420
        THEN
            RAISE EXCEPTION 'M08: Wide coverage failed';
        END IF;

        RAISE NOTICE 'PASS M08: Wide coverage for %',
            v_expected.report_date;


        -- M09: Verify wide export values and ordering without a full join.
        RAISE NOTICE 'RUN M09: Wide multiset comparison for %', v_expected.report_date;
        IF EXISTS (
            WITH expected AS MATERIALIZED (
                SELECT v_expected.report_date AS as_of_date,
                       m.customer_id,
                       v_expected.window_start AS window_start,
                       v_expected.partial_month AS is_partial_month,
                       array_agg(m.monthly_spending ORDER BY m.order_month) AS spending,
                       sum(m.monthly_spending) AS window_spending,
                       sum(m.monthly_order_count)::bigint AS window_order_count
                FROM public.customer_monthly_spending(v_expected.report_date) m
                GROUP BY m.customer_id
            ), actual AS MATERIALIZED (
                SELECT a.as_of_date, a.customer_id, a.window_start, a.is_partial_month,
                       ARRAY[a.month_01, a.month_02, a.month_03, a.month_04,
                             a.month_05, a.month_06, a.month_07, a.month_08,
                             a.month_09, a.month_10, a.month_11, a.month_12] AS spending,
                       a.window_spending, a.window_order_count
                FROM public.customer_monthly_spending_wide(v_expected.report_date) a
            )
            (SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
            UNION ALL
            (SELECT * FROM actual EXCEPT ALL SELECT * FROM expected)
        ) THEN
            RAISE EXCEPTION 'M09: Wide export mismatch';
        END IF;
        RAISE NOTICE 'PASS M09: Wide export values for %', v_expected.report_date;

    END LOOP;


    -- M10: Empty historical reporting window.
    RAISE NOTICE 'RUN M10: Empty historical reporting window.';

    SELECT
        COUNT(*) AS report_rows,

        SUM(monthly_spending) AS spending,

        SUM(monthly_order_count) AS order_count,

        COUNT(*) FILTER (
            WHERE is_partial_month
        ) AS partial_rows

    INTO v_actual

    FROM public.customer_monthly_spending(
        DATE '2025-01-31'
    );

    IF v_actual.report_rows <> 485040

       OR v_actual.spending IS DISTINCT FROM 0

       OR v_actual.order_count IS DISTINCT FROM 0

       OR v_actual.partial_rows <> 0

       OR EXISTS (

           SELECT 1

           FROM public.customer_monthly_spending_sparse(
               DATE '2025-01-31'
           )

       )

    THEN
        RAISE EXCEPTION 'M10: Empty window failed';
    END IF;

    RAISE NOTICE 'PASS M10: Empty historical window';


    -- M11: NULL date handling.
    RAISE NOTICE 'RUN M11: NULL date handling.';

    IF EXISTS (
        SELECT *
        FROM public.monthly_reporting_metadata(NULL::date)
    )

    OR EXISTS (
        SELECT *
        FROM public.customer_monthly_spending_sparse(NULL::date)
    )

    OR EXISTS (
        SELECT *
        FROM public.customer_monthly_spending(NULL::date)
    )

    OR EXISTS (
        SELECT *
        FROM public.customer_monthly_spending_wide(NULL::date)
    )

    THEN
        RAISE EXCEPTION 'M11: NULL date handling failed';
    END IF;

    RAISE NOTICE 'PASS M11: NULL date handling';


    -- M12: Historical baseline counts.
    RAISE NOTICE 'RUN M12: Historical baseline counts.';

    IF (SELECT COUNT(*) FROM public.categories) <> 94

       OR (SELECT COUNT(*) FROM public.customers) <> 40420

       OR (SELECT COUNT(*) FROM public.products) <> 4023

       OR (SELECT COUNT(*) FROM public.orders) <> 159384

       OR (SELECT COUNT(*) FROM public.order_items) <> 336559

       OR (SELECT COUNT(*) FROM public.inventory_log) <> 282352

    THEN
        RAISE EXCEPTION 'M12: Historical baseline mismatch';
    END IF;

    RAISE NOTICE 'PASS M12: Historical baseline reconciles';

    RAISE NOTICE
        'RESULT: All 12 monthly reporting check groups passed';

END;

$test$;

ROLLBACK;