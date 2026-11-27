-- DE-03: Kloud Kart
-- Stage 04.4: Trailing twelve-month customer spending
-- Decisions: D016, D019, D025-D029

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect reporting database';
    END IF;
END;
$guard$;


\echo === 1. Reporting window metadata ===

CREATE OR REPLACE FUNCTION
public.monthly_reporting_metadata(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    window_start date,
    window_end_exclusive timestamp,
    month_count integer,
    is_partial_month boolean,
    coverage_warning text
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    SELECT
        p_as_of_date,

        (
            DATE_TRUNC('month', p_as_of_date::timestamp)
            - INTERVAL '11 months'
        )::date,

        p_as_of_date + INTERVAL '1 day',

        12,

        EXTRACT(DAY FROM p_as_of_date + 1) <> 1,

        'Zero orders means no eligible records were found. '
        'Source-data completeness is not independently '
        'verified. The supplied baseline has unusually '
        'sparse activity after August 2026.'::text;

$function$;


\echo === 2. Sparse monthly spending aggregate ===

CREATE OR REPLACE FUNCTION
public.customer_monthly_spending_sparse(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    order_month date,
    monthly_spending numeric,
    monthly_order_count bigint
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    SELECT
        p_as_of_date,

        e.customer_id,

        DATE_TRUNC(
            'month',
            e.order_date
        )::date,

        SUM(e.total_amount),

        COUNT(*)

    FROM public.eligible_orders_as_of(
        p_as_of_date
    ) e

    JOIN public.customers c
        ON c.customer_id = e.customer_id

    WHERE e.order_date >= (
        DATE_TRUNC('month', p_as_of_date::timestamp)
        - INTERVAL '11 months'
    )

    GROUP BY
        e.customer_id,
        DATE_TRUNC('month', e.order_date)::date;

$function$;


\echo === 3. Dense monthly spending report ===

CREATE OR REPLACE FUNCTION
public.customer_monthly_spending(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    order_month date,
    monthly_spending numeric,
    monthly_order_count bigint,
    is_partial_month boolean
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    WITH months AS (

        SELECT
            GENERATE_SERIES(

                DATE_TRUNC(
                    'month',
                    p_as_of_date::timestamp
                ) - INTERVAL '11 months',

                DATE_TRUNC(
                    'month',
                    p_as_of_date::timestamp
                ),

                INTERVAL '1 month'

            )::date AS order_month

    ),

    monthly_activity AS (

        SELECT *

        FROM public.customer_monthly_spending_sparse(
            p_as_of_date
        )

    )

    SELECT
        p_as_of_date,

        c.customer_id,

        m.order_month,

        COALESCE(a.monthly_spending, 0::numeric),

        COALESCE(a.monthly_order_count, 0::bigint),

        (
            m.order_month =
                DATE_TRUNC(
                    'month',
                    p_as_of_date::timestamp
                )::date

            AND EXTRACT(
                DAY FROM p_as_of_date + 1
            ) <> 1
        )

    FROM public.customers c

    CROSS JOIN months m

    LEFT JOIN monthly_activity a
        ON a.customer_id = c.customer_id

       AND a.order_month = m.order_month;

$function$;


\echo === 4. Wide-format spending export ===

CREATE OR REPLACE FUNCTION
public.customer_monthly_spending_wide(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    window_start date,
    is_partial_month boolean,
    month_01 numeric,
    month_02 numeric,
    month_03 numeric,
    month_04 numeric,
    month_05 numeric,
    month_06 numeric,
    month_07 numeric,
    month_08 numeric,
    month_09 numeric,
    month_10 numeric,
    month_11 numeric,
    month_12 numeric,
    window_spending numeric,
    window_order_count bigint
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    WITH customer_export AS (

        SELECT
            m.customer_id,

            MIN(m.order_month) AS window_start,

            BOOL_OR(m.is_partial_month)
                AS is_partial_month,

            ARRAY_AGG(
                m.monthly_spending
                ORDER BY m.order_month
            ) AS spending,

            SUM(m.monthly_spending)
                AS window_spending,

            SUM(m.monthly_order_count)::bigint
                AS window_order_count

        FROM public.customer_monthly_spending(
            p_as_of_date
        ) m

        GROUP BY m.customer_id

    )

    SELECT
        p_as_of_date,
        e.customer_id,
        e.window_start,
        e.is_partial_month,

        e.spending[1],
        e.spending[2],
        e.spending[3],
        e.spending[4],
        e.spending[5],
        e.spending[6],
        e.spending[7],
        e.spending[8],
        e.spending[9],
        e.spending[10],
        e.spending[11],
        e.spending[12],

        e.window_spending,
        e.window_order_count

    FROM customer_export e;

$function$;


COMMENT ON FUNCTION
public.monthly_reporting_metadata(date) IS
'Returns the twelve-month reporting boundaries,
 partial-month indicator and source coverage warning.';

COMMENT ON FUNCTION
public.customer_monthly_spending_sparse(date) IS
'Aggregates attributed eligible orders to
 customer-month grain within the reporting window.';

COMMENT ON FUNCTION
public.customer_monthly_spending(date) IS
'Returns twelve monthly records per existing
 customer, including zero-order months.';

COMMENT ON FUNCTION
public.customer_monthly_spending_wide(date) IS
'Optional wide-format spending export.
 Month_01 is the oldest reporting month.
 Month_12 is the as-of month.
 Retrieve reporting metadata alongside exports.';

COMMIT;