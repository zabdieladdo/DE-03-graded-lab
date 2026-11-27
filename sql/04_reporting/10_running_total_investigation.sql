-- DE-03: Kloud Kart
-- Stage 04.5: Running total investigation

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. Opening balances and window totals ===

WITH dates AS (

    SELECT *
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)

),

totals AS (

    SELECT
        d.as_of_date,

        c.customer_id,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date <
                    DATE_TRUNC(
                        'month',
                        d.as_of_date::timestamp
                    ) - INTERVAL '11 months'
            ),
            0
        ) AS opening_spending,

        COUNT(o.order_id) FILTER (
            WHERE o.order_date <
                DATE_TRUNC(
                    'month',
                    d.as_of_date::timestamp
                ) - INTERVAL '11 months'
        ) AS opening_orders,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date >=
                    DATE_TRUNC(
                        'month',
                        d.as_of_date::timestamp
                    ) - INTERVAL '11 months'
            ),
            0
        ) AS window_spending,

        COUNT(o.order_id) FILTER (
            WHERE o.order_date >=
                DATE_TRUNC(
                    'month',
                    d.as_of_date::timestamp
                ) - INTERVAL '11 months'
        ) AS window_orders

    FROM dates d

    CROSS JOIN public.customers c

    LEFT JOIN public.orders o
        ON o.customer_id = c.customer_id

       AND LOWER(BTRIM(o.status))
            IN ('completed', 'complete')

       AND o.order_date <
            d.as_of_date + INTERVAL '1 day'

    GROUP BY
        d.as_of_date,
        c.customer_id

)

SELECT
    as_of_date,

    COUNT(*) AS customers,

    COUNT(*) FILTER (
        WHERE opening_orders > 0
    ) AS customers_with_opening_orders,

    COUNT(*) FILTER (
        WHERE opening_spending <> 0
    ) AS customers_with_nonzero_opening,

    COUNT(*) FILTER (
        WHERE opening_orders > 0
          AND window_orders = 0
    ) AS opening_only_customers,

    SUM(opening_orders) AS opening_orders,

    SUM(opening_spending) AS opening_spending,

    SUM(window_orders) AS window_orders,

    SUM(window_spending) AS window_spending,

    SUM(
        opening_spending + window_spending
    ) AS lifetime_spending

FROM totals

GROUP BY as_of_date

ORDER BY as_of_date;


\echo === 2. Customer 100001 cumulative spending ===

WITH opening AS (

    SELECT
        COALESCE(
            SUM(total_amount),
            0
        ) AS opening_spending

    FROM public.orders

    WHERE customer_id = 100001

      AND LOWER(BTRIM(status))
            IN ('completed', 'complete')

      AND order_date < DATE '2025-09-01'

),

monthly AS (

    SELECT
        order_month,

        monthly_spending,

        monthly_order_count,

        SUM(monthly_spending) OVER (

            ORDER BY order_month

            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS window_running

    FROM public.customer_monthly_spending(
        DATE '2026-08-31'
    )

    WHERE customer_id = 100001

)

SELECT
    m.*,

    o.opening_spending,

    o.opening_spending + m.window_running
        AS lifetime_running

FROM monthly m

CROSS JOIN opening o

ORDER BY order_month;


\echo === 3. Transaction timestamp ties ===

WITH ties AS (

    SELECT
        o.customer_id,

        o.order_date,

        COUNT(*) AS orders_at_timestamp

    FROM public.orders o

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
            IN ('completed', 'complete')

      AND o.order_date < DATE '2026-09-01'

    GROUP BY
        o.customer_id,
        o.order_date

    HAVING COUNT(*) > 1

)

SELECT
    COUNT(*) AS tied_groups,

    COUNT(DISTINCT customer_id)
        AS affected_customers,

    COALESCE(
        SUM(orders_at_timestamp),
        0
    ) AS affected_orders,

    COALESCE(
        MAX(orders_at_timestamp),
        0
    ) AS largest_tie

FROM ties;

ROLLBACK;