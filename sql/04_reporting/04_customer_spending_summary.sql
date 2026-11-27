-- DE-03: Kloud Kart
-- Stage 04.3: Customer spending and order counts
--
-- Decisions: D016, D019, D025, D026, D027
--
-- One row per existing customer.
-- Recorded eligible order value, not verified payments.

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


\echo === 1. Customer spending summary ===

CREATE OR REPLACE FUNCTION public.customer_spending_summary(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    customer_id integer,
    full_name text,
    total_spent numeric,
    order_count bigint,
    first_order_date timestamp without time zone,
    last_order_date timestamp without time zone
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    WITH spending AS (

        SELECT
            e.customer_id,

            SUM(e.total_amount) AS total_spent,

            COUNT(*) AS order_count,

            MIN(e.order_date) AS first_order_date,

            MAX(e.order_date) AS last_order_date

        FROM public.eligible_orders_as_of(
            p_as_of_date
        ) e

        GROUP BY e.customer_id

    )

    SELECT
        p_as_of_date,
        c.customer_id,
        c.full_name,

        COALESCE(s.total_spent, 0::numeric),

        COALESCE(s.order_count, 0::bigint),

        s.first_order_date,
        s.last_order_date

    FROM public.customers c

    LEFT JOIN spending s
        ON s.customer_id = c.customer_id;

$function$;


COMMENT ON FUNCTION
public.customer_spending_summary(date) IS
'Returns one row per current customer account,
 including accounts without eligible orders.
 Spending is based on recorded eligible order
 totals through the supplied date inclusive.
 Historical customer identities remain separate.
 Unattributed orders are reconciled separately.';


\echo === 2. Spending attribution reconciliation ===

CREATE OR REPLACE FUNCTION public.spending_reconciliation(
    p_as_of_date date
)

RETURNS TABLE (
    as_of_date date,
    eligible_orders bigint,
    eligible_value numeric,
    attributed_orders bigint,
    attributed_value numeric,
    unattributed_orders bigint,
    unattributed_value numeric
)

LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER

AS $function$

    SELECT
        p_as_of_date,

        COUNT(*),

        COALESCE(SUM(e.total_amount), 0),

        COUNT(c.customer_id),

        COALESCE(
            SUM(e.total_amount) FILTER (
                WHERE c.customer_id IS NOT NULL
            ), 0
        ),

        COUNT(*) FILTER (
            WHERE c.customer_id IS NULL
        ),

        COALESCE(
            SUM(e.total_amount) FILTER (
                WHERE c.customer_id IS NULL
            ), 0
        )

    FROM public.eligible_orders_as_of(
        p_as_of_date
    ) e

    LEFT JOIN public.customers c
        ON c.customer_id = e.customer_id;

$function$;


COMMENT ON FUNCTION
public.spending_reconciliation(date) IS
'Reconciles eligible recorded order values into
 attributed and unattributed amounts through the
 supplied reporting date inclusive.';


COMMIT;