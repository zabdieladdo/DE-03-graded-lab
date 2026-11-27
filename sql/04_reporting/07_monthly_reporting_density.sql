-- DE-03: Kloud Kart
-- Stage 04.4: Monthly reporting design investigation

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


\echo === 1. Sparse versus dense reporting volume ===

WITH reporting_dates AS (

    SELECT DATE '2026-08-31' AS as_of_date

    UNION ALL

    SELECT DATE '2026-11-26'

),

reporting_windows AS (

    SELECT
        as_of_date,

        (
            DATE_TRUNC('month', as_of_date)
            - INTERVAL '11 months'
        )::date AS window_start

    FROM reporting_dates

),

monthly_activity AS (

    SELECT
        w.as_of_date,
        e.customer_id,

        DATE_TRUNC(
            'month',
            e.order_date
        )::date AS order_month,

        COUNT(*) AS order_count,
        SUM(e.total_amount) AS monthly_spending

    FROM reporting_windows w

    CROSS JOIN LATERAL
        public.eligible_orders_as_of(
            w.as_of_date
        ) e

    JOIN public.customers c
        ON c.customer_id = e.customer_id

    WHERE e.order_date >= w.window_start

    GROUP BY
        w.as_of_date,
        e.customer_id,
        DATE_TRUNC('month', e.order_date)::date

),

population AS (

    SELECT COUNT(*) AS customer_count
    FROM public.customers

)

SELECT
    w.as_of_date,
    w.window_start,

    p.customer_count,

    p.customer_count * 12 AS dense_rows,

    COUNT(m.customer_id) AS sparse_rows,

    p.customer_count * 12
        - COUNT(m.customer_id) AS zero_order_months,

    ROUND(

        100.0 * (
            p.customer_count * 12
            - COUNT(m.customer_id)
        ) / NULLIF(p.customer_count * 12, 0),

        2

    ) AS zero_order_month_pct,

    COUNT(DISTINCT m.customer_id)
        AS customers_with_window_orders,

    COALESCE(SUM(m.order_count), 0)
        AS attributed_orders,

    COALESCE(SUM(m.monthly_spending), 0)
        AS attributed_spending

FROM reporting_windows w

CROSS JOIN population p

LEFT JOIN monthly_activity m
    ON m.as_of_date = w.as_of_date

GROUP BY
    w.as_of_date,
    w.window_start,
    p.customer_count

ORDER BY w.as_of_date;


\echo === 2. Distribution of active months per customer ===

WITH active_months AS (

    SELECT
        e.customer_id,

        COUNT(
            DISTINCT DATE_TRUNC(
                'month',
                e.order_date
            )
        ) AS months_with_orders

    FROM public.eligible_orders_as_of(
        DATE '2026-08-31'
    ) e

    WHERE e.order_date >= DATE '2025-09-01'

    GROUP BY e.customer_id

)

SELECT
    COALESCE(a.months_with_orders, 0)
        AS active_months,

    COUNT(*) AS customer_count

FROM public.customers c

LEFT JOIN active_months a
    ON a.customer_id = c.customer_id

GROUP BY COALESCE(a.months_with_orders, 0)

ORDER BY active_months;


\echo === 3. Headline monthly attributed spending ===

WITH months AS (

    SELECT
        GENERATE_SERIES(
            TIMESTAMP '2025-09-01',
            TIMESTAMP '2026-08-01',
            INTERVAL '1 month'
        )::date AS order_month

),

monthly_activity AS (

    SELECT
        DATE_TRUNC(
            'month',
            e.order_date
        )::date AS order_month,

        COUNT(*) AS order_count,

        COUNT(DISTINCT e.customer_id)
            AS purchasing_customers,

        SUM(e.total_amount) AS monthly_spending

    FROM public.eligible_orders_as_of(
        DATE '2026-08-31'
    ) e

    JOIN public.customers c
        ON c.customer_id = e.customer_id

    WHERE e.order_date >= DATE '2025-09-01'

    GROUP BY
        DATE_TRUNC('month', e.order_date)::date

)

SELECT
    m.order_month,

    COALESCE(a.order_count, 0)
        AS attributed_orders,

    COALESCE(a.purchasing_customers, 0)
        AS purchasing_customers,

    COALESCE(a.monthly_spending, 0)
        AS attributed_spending

FROM months m

LEFT JOIN monthly_activity a
    ON a.order_month = m.order_month

ORDER BY m.order_month;


ROLLBACK;