-- DE-03: Kloud Kart
-- Stage 04.1B: Reporting date investigation
-- Read-only diagnostic investigation.

\set ON_ERROR_STOP on
\pset pager off
\timing on

\set as_of_date '2026-11-26'
\set main_period_end '2026-08-31'

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


\echo === 1. Investigation parameters ===

SELECT
    :'as_of_date'::date AS as_of_date,
    :'main_period_end'::date AS main_period_end;


\echo === 2. Orders after the main dataset period ===

WITH item_totals AS (

    SELECT
        oi.order_id,
        COUNT(*) AS item_count,
        SUM(oi.quantity * oi.unit_price) AS item_value,
        COUNT(*) FILTER (
            WHERE oi.unit_price IS NULL
        ) AS missing_prices,
        MAX(oi.quantity) AS maximum_quantity

    FROM order_items oi

    JOIN orders o
        ON o.order_id = oi.order_id

    WHERE o.order_date >=
        :'main_period_end'::date + 1

    GROUP BY oi.order_id

)

SELECT
    o.order_id,
    o.order_date,
    o.customer_id,
    o.status,
    o.total_amount,

    CASE
        WHEN LOWER(BTRIM(o.status)) IN (
            'completed', 'complete'
        ) THEN 'ELIGIBLE'
        ELSE 'NOT ELIGIBLE'
    END AS spending_status,

    CASE
        WHEN o.order_date >= :'as_of_date'::date + 1
            THEN 'FUTURE DATED'
        ELSE 'AFTER MAIN PERIOD'
    END AS date_classification,

    CASE
        WHEN c.customer_id IS NULL
            THEN 'MISSING CUSTOMER'
        WHEN c.registered_at IS NULL
            THEN 'UNKNOWN REGISTRATION'
        WHEN o.order_date < c.registered_at
            THEN 'BEFORE REGISTRATION'
        ELSE 'NO DATE CONFLICT'
    END AS customer_check,

    COALESCE(i.item_count, 0) AS item_count,
    i.item_value,
    i.missing_prices,
    i.maximum_quantity,

    CASE
        WHEN i.item_count IS NULL
            THEN 'NO ITEMS'
        WHEN i.missing_prices > 0
            THEN 'INCOMPLETE PRICES'
        WHEN o.total_amount = i.item_value
            THEN 'MATCH'
        ELSE 'DIFFERENCE'
    END AS financial_check

FROM orders o

LEFT JOIN customers c
    ON c.customer_id = o.customer_id

LEFT JOIN item_totals i
    ON i.order_id = o.order_id

WHERE o.order_date >=
    :'main_period_end'::date + 1

ORDER BY o.order_date, o.order_id;


\echo === 3. Future-dated order status distribution ===

SELECT
    status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS recorded_order_value

FROM orders

WHERE order_date >= :'as_of_date'::date + 1

GROUP BY status

ORDER BY order_count DESC, status;


\echo === 4. Future-dated eligible order attribution ===

SELECT
    COUNT(*) AS eligible_future_orders,

    COALESCE(SUM(o.total_amount), 0)
        AS eligible_future_value,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NOT NULL
    ) AS attributed_orders,

    COALESCE(
        SUM(o.total_amount) FILTER (
            WHERE c.customer_id IS NOT NULL
        ), 0
    ) AS attributed_value,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NULL
    ) AS unattributed_orders,

    COALESCE(
        SUM(o.total_amount) FILTER (
            WHERE c.customer_id IS NULL
        ), 0
    ) AS unattributed_value,

    COUNT(DISTINCT c.customer_id)
        AS affected_existing_customers

FROM orders o

LEFT JOIN customers c
    ON c.customer_id = o.customer_id

WHERE o.order_date >= :'as_of_date'::date + 1

  AND LOWER(BTRIM(o.status)) IN (
      'completed', 'complete'
  );


\echo === 5. Reporting date sensitivity ===

WITH reporting_windows AS (

    SELECT
        'S1 - Unrestricted' AS scenario,
        NULL::timestamp AS start_date,
        NULL::timestamp AS end_exclusive

    UNION ALL

    SELECT
        'S2 - All history as of reporting date',
        NULL::timestamp,
        (:'as_of_date'::date + 1)::timestamp

    UNION ALL

    SELECT
        'S3 - Current month plus previous 11',
        DATE_TRUNC(
            'month', :'as_of_date'::date::timestamp
        ) - INTERVAL '11 months',
        (:'as_of_date'::date + 1)::timestamp

    UNION ALL

    SELECT
        'S4 - Last 12 completed months',
        DATE_TRUNC(
            'month', :'as_of_date'::date::timestamp
        ) - INTERVAL '12 months',
        DATE_TRUNC(
            'month', :'as_of_date'::date::timestamp
        )

    UNION ALL

    SELECT
        'S5 - Main dataset period, 12 months',
        DATE_TRUNC(
            'month', :'main_period_end'::date::timestamp
        ) - INTERVAL '11 months',
        (:'main_period_end'::date + 1)::timestamp

    UNION ALL

    SELECT
        'S6 - Latest order month, 12 months',
        DATE_TRUNC('month', MAX(order_date))
            - INTERVAL '11 months',
        MAX(order_date) + INTERVAL '1 microsecond'
    FROM orders

),

eligible_orders AS (

    SELECT
        o.order_id,
        o.order_date,
        o.total_amount,
        c.customer_id AS existing_customer_id

    FROM orders o

    LEFT JOIN customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status)) IN (
        'completed', 'complete'
    )

)

SELECT
    w.scenario,
    w.start_date,
    w.end_exclusive,

    COUNT(e.order_id) AS eligible_orders,

    COALESCE(SUM(e.total_amount), 0)
        AS eligible_value,

    COUNT(e.existing_customer_id)
        AS attributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE e.existing_customer_id IS NOT NULL
        ), 0
    ) AS attributed_value,

    COUNT(e.order_id) FILTER (
        WHERE e.existing_customer_id IS NULL
    ) AS unattributed_orders,

    COALESCE(
        SUM(e.total_amount) FILTER (
            WHERE e.existing_customer_id IS NULL
        ), 0
    ) AS unattributed_value,

    COUNT(DISTINCT e.existing_customer_id)
        AS customers_with_eligible_orders

FROM reporting_windows w

LEFT JOIN eligible_orders e

    ON (
        w.start_date IS NULL
        OR e.order_date >= w.start_date
    )

    AND (
        w.end_exclusive IS NULL
        OR e.order_date < w.end_exclusive
    )

GROUP BY
    w.scenario,
    w.start_date,
    w.end_exclusive

ORDER BY w.scenario;


\echo === 6. Top-100 ranking sensitivity ===

WITH customer_spending AS (

    SELECT
        c.customer_id,

        COALESCE(SUM(o.total_amount), 0)
            AS unrestricted_spending,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date <
                    :'as_of_date'::date + 1
            ), 0
        ) AS as_of_spending

    FROM customers c

    LEFT JOIN orders o
        ON o.customer_id = c.customer_id
       AND LOWER(BTRIM(o.status)) IN (
           'completed', 'complete'
       )

    GROUP BY c.customer_id

),

ranked AS (

    SELECT
        customer_id,
        unrestricted_spending,
        as_of_spending,

        ROW_NUMBER() OVER (
            ORDER BY
                unrestricted_spending DESC,
                customer_id
        ) AS unrestricted_rank,

        ROW_NUMBER() OVER (
            ORDER BY
                as_of_spending DESC,
                customer_id
        ) AS as_of_rank

    FROM customer_spending

)

SELECT

    COUNT(*) FILTER (
        WHERE unrestricted_rank <= 100
    ) AS unrestricted_top_100,

    COUNT(*) FILTER (
        WHERE as_of_rank <= 100
    ) AS as_of_top_100,

    COUNT(*) FILTER (
        WHERE unrestricted_rank <= 100
          AND as_of_rank <= 100
    ) AS retained_top_100,

    COUNT(*) FILTER (
        WHERE unrestricted_rank <= 100
          AND as_of_rank > 100
    ) AS customers_leaving_top_100,

    COUNT(*) FILTER (
        WHERE unrestricted_rank > 100
          AND as_of_rank <= 100
    ) AS customers_entering_top_100,

    COUNT(*) FILTER (
        WHERE unrestricted_spending
            IS DISTINCT FROM as_of_spending
    ) AS customers_with_changed_spending,

    SUM(unrestricted_spending - as_of_spending)
        AS excluded_attributed_value

FROM ranked;


ROLLBACK;