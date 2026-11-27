
-- DE-03: Kloud Kart
-- Stage 04.5: Initial running spending inspection
-- Evidence: E042a

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


\echo === 1. Monthly running report sample ===

SELECT *
FROM public.customer_monthly_running_spending(
    DATE '2026-08-31'
)
WHERE customer_id = 100001
ORDER BY order_month;


\echo === 2. Transaction running report sample ===

SELECT *
FROM public.customer_order_running_spending(
    DATE '2026-08-31'
)
WHERE customer_id = 100001
ORDER BY order_date, order_id;


\echo === 3. Customer with historical opening spending ===

WITH report AS MATERIALIZED (

    SELECT *
    FROM public.customer_monthly_running_spending(
        DATE '2026-08-31'
    )

),

selected_customer AS (

    SELECT MIN(customer_id) AS customer_id

    FROM report

    WHERE opening_spending > 0

)

SELECT r.*

FROM report r

JOIN selected_customer c
    ON c.customer_id = r.customer_id

ORDER BY r.order_month;


\echo === 4. Opening-only customer sample ===

WITH report AS MATERIALIZED (

    SELECT *
    FROM public.customer_monthly_running_spending(
        DATE '2026-08-31'
    )

),

selected_customer AS (

    SELECT customer_id

    FROM report

    GROUP BY customer_id

    HAVING MAX(opening_spending) > 0
       AND SUM(monthly_order_count) = 0

    ORDER BY customer_id

    LIMIT 1

)

SELECT r.*

FROM report r

JOIN selected_customer c
    ON c.customer_id = r.customer_id

ORDER BY r.order_month;


\echo === 5. Final monthly balance reconciliation ===

WITH report AS (

    SELECT *

    FROM public.customer_monthly_running_spending(
        DATE '2026-08-31'
    )

)

SELECT
    COUNT(*) AS customers,

    SUM(opening_spending)
        AS opening_spending,

    SUM(window_cumulative_spending)
        AS final_window_spending,

    SUM(cumulative_since_extract_start)
        AS final_recorded_history_spending

FROM report

WHERE order_month = DATE '2026-08-01';


\echo === 6. Transaction report reconciliation ===

SELECT
    COUNT(*) AS attributed_orders,

    COUNT(DISTINCT customer_id)
        AS purchasing_customers,

    COUNT(*) FILTER (
        WHERE NOT is_in_reporting_window
    ) AS opening_orders,

    COUNT(*) FILTER (
        WHERE is_in_reporting_window
    ) AS window_orders,

    COUNT(*) FILTER (
        WHERE NOT is_in_reporting_window
          AND window_cumulative_spending IS NOT NULL
    ) AS invalid_prewindow_balances,

    SUM(order_amount)
        AS recorded_spending

FROM public.customer_order_running_spending(
    DATE '2026-08-31'
);

ROLLBACK;
