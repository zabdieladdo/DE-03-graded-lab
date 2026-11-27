
-- DE-03: Kloud Kart
-- Stage 04.5: Customer running spending
-- Decision: D030
-- Evidence: E042

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


-- =========================================================
-- 1. Monthly running spending
-- Grain: one customer per calendar month
-- =========================================================

CREATE OR REPLACE FUNCTION
    public.customer_monthly_running_spending(
        p_as_of_date date
    )

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    order_month date,
    monthly_spending numeric,
    monthly_order_count bigint,
    opening_spending numeric,
    window_cumulative_spending numeric,
    cumulative_since_extract_start numeric,
    is_partial_month boolean
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    WITH opening_balances AS (

        SELECT
            e.customer_id,

            SUM(e.total_amount)
                AS opening_spending

        FROM public.eligible_orders_as_of(
            p_as_of_date
        ) e

        JOIN public.customers c
            ON c.customer_id = e.customer_id

        WHERE e.order_date <
            DATE_TRUNC(
                'month',
                p_as_of_date::timestamp
            ) - INTERVAL '11 months'

        GROUP BY e.customer_id

    ),

    monthly_running AS (

        SELECT
            m.as_of_date,
            m.customer_id,
            m.order_month,
            m.monthly_spending,
            m.monthly_order_count,
            m.is_partial_month,

            SUM(m.monthly_spending) OVER (

                PARTITION BY m.customer_id

                ORDER BY m.order_month

                ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW

            ) AS window_cumulative_spending

        FROM public.customer_monthly_spending(
            p_as_of_date
        ) m

    )

    SELECT
        m.as_of_date,
        m.customer_id,
        m.order_month,
        m.monthly_spending,
        m.monthly_order_count,

        COALESCE(
            o.opening_spending,
            0::numeric
        ) AS opening_spending,

        m.window_cumulative_spending,

        COALESCE(
            o.opening_spending,
            0::numeric
        ) + m.window_cumulative_spending
            AS cumulative_since_extract_start,

        m.is_partial_month

    FROM monthly_running m

    LEFT JOIN opening_balances o
        ON o.customer_id = m.customer_id;

$function$;


COMMENT ON FUNCTION
    public.customer_monthly_running_spending(date)

IS 'D030: One row per current customer per reporting month.
Window cumulative spending begins at the trailing twelve-month
window start. Cumulative since extract start includes recorded
eligible spending before the window. Historical completeness
and actual lifetime payments are not established.';


-- =========================================================
-- 2. Transaction-level running spending
-- Grain: one attributed eligible order
-- =========================================================

CREATE OR REPLACE FUNCTION
    public.customer_order_running_spending(
        p_as_of_date date
    )

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    order_id integer,
    order_date timestamp without time zone,
    order_amount numeric,
    is_in_reporting_window boolean,
    window_cumulative_spending numeric,
    cumulative_since_extract_start numeric
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    WITH attributed_orders AS (

        SELECT
            e.customer_id,
            e.order_id,
            e.order_date,
            e.total_amount,

            e.order_date >= (
                DATE_TRUNC(
                    'month',
                    p_as_of_date::timestamp
                ) - INTERVAL '11 months'
            ) AS is_in_reporting_window

        FROM public.eligible_orders_as_of(
            p_as_of_date
        ) e

        JOIN public.customers c
            ON c.customer_id = e.customer_id

    )

    SELECT
        p_as_of_date,
        a.customer_id,
        a.order_id,
        a.order_date,
        a.total_amount,
        a.is_in_reporting_window,

        CASE

            WHEN a.is_in_reporting_window

            THEN SUM(a.total_amount) FILTER (
                WHERE a.is_in_reporting_window
            ) OVER customer_history

            ELSE NULL::numeric

        END AS window_cumulative_spending,

        SUM(a.total_amount) OVER customer_history
            AS cumulative_since_extract_start

    FROM attributed_orders a

    WINDOW customer_history AS (

        PARTITION BY a.customer_id

        ORDER BY
            a.order_date,
            a.order_id

        ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW

    );

$function$;


COMMENT ON FUNCTION
    public.customer_order_running_spending(date)

IS 'D030: One row per attributed eligible order through the
reporting cutoff. Uses recorded timestamps and order IDs
for deterministic cumulative calculations. Pre-window orders
have NULL window cumulative spending. Unattributed orders
remain outside customer totals.';


COMMIT;

\echo === Running spending functions deployed ===
