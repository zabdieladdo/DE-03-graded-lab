-- DE-03: Kloud Kart
-- Stage 04.5: Supplementary running-total investigation
-- Evidence 41a

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === 1. Observed order history coverage ===

SELECT
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    MIN(order_date) FILTER (
        WHERE LOWER(BTRIM(status))
            IN ('completed', 'complete')
    ) AS earliest_eligible_order,
    COUNT(*) AS total_orders
FROM public.orders;


\echo === 2. Customer registration before observed order history ===

WITH coverage AS (
    SELECT MIN(order_date) AS first_order
    FROM public.orders
)

SELECT
    b.first_order AS earliest_observed_order,

    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE c.registered_at < b.first_order
    ) AS registered_before_first_order,

    COUNT(*) FILTER (
        WHERE c.registered_at < b.first_order::date
    ) AS registered_before_first_order_day,

    COUNT(*) FILTER (
        WHERE c.registered_at <
            DATE_TRUNC('month', b.first_order)
    ) AS registered_before_first_order_month,

    COUNT(*) FILTER (
        WHERE c.registered_at IS NULL
    ) AS missing_registration_dates,

    MIN(c.registered_at)
        AS earliest_registration,

    MAX(c.registered_at)
        AS latest_registration

FROM public.customers c
CROSS JOIN coverage b
GROUP BY b.first_order;


\echo === 3. Eligible order frame comparison ===

WITH reporting_dates AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)
),

eligible AS (
    SELECT
        d.as_of_date,
        o.customer_id,
        o.order_id,
        o.order_date,
        o.total_amount

    FROM reporting_dates d

    JOIN public.orders o
        ON o.order_date <
            d.as_of_date + INTERVAL '1 day'

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')
),

comparison AS (
    SELECT
        *,

        SUM(total_amount) OVER (
            PARTITION BY as_of_date, customer_id
            ORDER BY order_date::date, order_id
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS day_rows_total,

        SUM(total_amount) OVER (
            PARTITION BY as_of_date, customer_id
            ORDER BY order_date::date
            RANGE BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS day_range_total,

        SUM(total_amount) OVER (
            PARTITION BY as_of_date, customer_id
            ORDER BY order_date, order_id
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS transaction_rows_total

    FROM eligible
)

SELECT
    as_of_date,

    COUNT(*) AS compared_orders,

    COUNT(*) FILTER (
        WHERE day_rows_total
            IS DISTINCT FROM day_range_total
    ) AS differing_day_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE day_rows_total
                IS DISTINCT FROM day_range_total
        ) / NULLIF(COUNT(*), 0),
        4
    ) AS differing_day_pct,

    COUNT(DISTINCT customer_id) FILTER (
        WHERE day_rows_total
            IS DISTINCT FROM day_range_total
    ) AS affected_customers,

    COUNT(*) FILTER (
        WHERE day_rows_total
            IS DISTINCT FROM transaction_rows_total
    ) AS day_id_vs_timestamp_order_differences

FROM comparison
GROUP BY as_of_date
ORDER BY as_of_date;


\echo === 4. Exact timestamp ties for both cutoffs ===

WITH reporting_dates AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)
),

ties AS (
    SELECT
        d.as_of_date,
        o.customer_id,
        o.order_date,
        COUNT(*) AS tied_orders

    FROM reporting_dates d

    JOIN public.orders o
        ON o.order_date <
            d.as_of_date + INTERVAL '1 day'

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')

    GROUP BY
        d.as_of_date,
        o.customer_id,
        o.order_date

    HAVING COUNT(*) > 1
)

SELECT
    d.as_of_date,
    COUNT(t.customer_id) AS tied_groups,
    COUNT(DISTINCT t.customer_id)
        AS affected_customers,
    COALESCE(SUM(t.tied_orders), 0)
        AS affected_orders,
    COALESCE(MAX(t.tied_orders), 0)
        AS largest_tie

FROM reporting_dates d
LEFT JOIN ties t
    ON t.as_of_date = d.as_of_date

GROUP BY d.as_of_date
ORDER BY d.as_of_date;

ROLLBACK;