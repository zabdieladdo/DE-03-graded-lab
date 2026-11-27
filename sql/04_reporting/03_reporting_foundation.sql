-- DE-03: Kloud Kart
-- Stage 04.2: Reusable reporting foundation
--
-- Decisions: D016, D025, D026, D027
--
-- Preserve source records.
-- Separate status eligibility from reporting dates.

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


\echo === 1. Normalize order statuses ===

CREATE OR REPLACE VIEW public.v_orders_normalized AS

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status AS raw_status,

    CASE

        WHEN LOWER(BTRIM(o.status)) IN (
            'completed',
            'complete'
        ) THEN 'completed'

        WHEN LOWER(BTRIM(o.status)) = 'pending'
            THEN 'pending'

        WHEN LOWER(BTRIM(o.status)) = 'shipped'
            THEN 'shipped'

        WHEN LOWER(BTRIM(o.status)) IN (
            'cancelled',
            'canceled'
        ) THEN 'cancelled'

        WHEN LOWER(BTRIM(o.status)) = 'refunded'
            THEN 'refunded'

        ELSE 'unknown'

    END AS normalized_status,

    o.total_amount

FROM public.orders o;


COMMENT ON VIEW public.v_orders_normalized IS
'Normalizes known order status variations while
 preserving original status values and recorded
 order totals. Unknown statuses are not eligible.';


\echo === 2. Define spending eligibility ===

CREATE OR REPLACE VIEW public.v_eligible_orders AS

SELECT
    order_id,
    customer_id,
    order_date,
    raw_status,
    normalized_status,
    total_amount

FROM public.v_orders_normalized

WHERE normalized_status = 'completed';


COMMENT ON VIEW public.v_eligible_orders IS
'Completed-only spending eligibility policy.
 Includes all dates and preserves unattributed orders.
 Recorded order totals are not verified payments.';


\echo === 3. Parameterized as-of eligibility ===

CREATE OR REPLACE FUNCTION public.eligible_orders_as_of(
    p_as_of_date date
)

RETURNS SETOF public.v_eligible_orders

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    SELECT
        e.order_id,
        e.customer_id,
        e.order_date,
        e.raw_status,
        e.normalized_status,
        e.total_amount

    FROM public.v_eligible_orders e

    WHERE e.order_date <
        p_as_of_date + INTERVAL '1 day';

$function$;


COMMENT ON FUNCTION public.eligible_orders_as_of(date) IS
'Returns eligible orders through the supplied
 reporting date inclusive. Excludes missing dates
 and orders beyond the reporting cutoff.
 Uses currently stored order statuses.';


\echo === 4. Parameterized reporting date exceptions ===

CREATE OR REPLACE FUNCTION public.reporting_date_exceptions(
    p_as_of_date date
)

RETURNS TABLE (
    order_id integer,
    customer_id integer,
    order_date timestamp without time zone,
    raw_status text,
    normalized_status text,
    total_amount numeric,
    status_eligible boolean,
    as_of_date date,
    exclusion_reason text
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    SELECT
        n.order_id,
        n.customer_id,
        n.order_date,
        n.raw_status,
        n.normalized_status,
        n.total_amount,
        n.normalized_status = 'completed',
        p_as_of_date,

        CASE
            WHEN n.order_date IS NULL
                THEN 'MISSING_ORDER_DATE'
            ELSE 'AFTER_REPORTING_CUTOFF'
        END

    FROM public.v_orders_normalized n

    WHERE n.order_date IS NULL

       OR n.order_date >=
            p_as_of_date + INTERVAL '1 day';

$function$;


COMMENT ON FUNCTION public.reporting_date_exceptions(date) IS
'Identifies orders outside a supplied reporting
 cutoff, including missing dates. Exclusion does
 not establish that an underlying record is invalid.';


\echo === 5. Current future-dated order exceptions ===

CREATE OR REPLACE VIEW public.v_future_dated_orders AS

SELECT
    n.order_id,
    n.customer_id,
    n.order_date,
    n.raw_status,
    n.normalized_status,
    n.total_amount,

    n.normalized_status = 'completed'
        AS status_eligible,

    CURRENT_DATE AS observation_date

FROM public.v_orders_normalized n

WHERE n.order_date >=
    CURRENT_DATE + INTERVAL '1 day';


COMMENT ON VIEW public.v_future_dated_orders IS
'Identifies orders dated after the current database
 calendar date. This dynamic diagnostic view is
 distinct from historical reporting cutoffs.';


COMMIT;