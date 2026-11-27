
-- DE-03: Kloud Kart
-- Stage 04.6: Shared customer spending and ranking
-- Decision: D031
-- Evidence: E046

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


-- =====================================================
-- 1. Shared customer-level spending calculation
-- =====================================================

\echo === 1. Shared customer spending totals ===

CREATE OR REPLACE FUNCTION public.customer_spending_totals(
    p_as_of_date date
)
RETURNS TABLE (
    as_of_date date,
    window_start date,
    is_partial_month boolean,
    customer_id integer,
    full_name text,
    recorded_history_spending numeric,
    recorded_history_order_count bigint,
    opening_spending numeric,
    opening_order_count bigint,
    window_spending numeric,
    window_order_count bigint
)
LANGUAGE sql
STABLE
STRICT
SECURITY INVOKER
AS $function$

    WITH reporting_window AS (
        SELECT
            m.as_of_date,
            m.window_start,
            m.is_partial_month
        FROM public.monthly_reporting_metadata(
            p_as_of_date
        ) m
    ),

    customer_activity AS (
        SELECT
            e.customer_id,

            SUM(e.total_amount)
                AS recorded_history_spending,

            COUNT(*)
                AS recorded_history_order_count,

            SUM(e.total_amount) FILTER (
                WHERE e.order_date < w.window_start
            ) AS opening_spending,

            COUNT(*) FILTER (
                WHERE e.order_date < w.window_start
            ) AS opening_order_count,

            SUM(e.total_amount) FILTER (
                WHERE e.order_date >= w.window_start
            ) AS window_spending,

            COUNT(*) FILTER (
                WHERE e.order_date >= w.window_start
            ) AS window_order_count

        FROM public.eligible_orders_as_of(
            p_as_of_date
        ) e

        CROSS JOIN reporting_window w

        GROUP BY e.customer_id
    )

    SELECT
        w.as_of_date,
        w.window_start,
        w.is_partial_month,

        c.customer_id,
        c.full_name,

        COALESCE(
            a.recorded_history_spending,
            0::numeric
        ),

        COALESCE(
            a.recorded_history_order_count,
            0::bigint
        ),

        COALESCE(
            a.opening_spending,
            0::numeric
        ),

        COALESCE(
            a.opening_order_count,
            0::bigint
        ),

        COALESCE(
            a.window_spending,
            0::numeric
        ),

        COALESCE(
            a.window_order_count,
            0::bigint
        )

    FROM public.customers c

    CROSS JOIN reporting_window w

    LEFT JOIN customer_activity a
        ON a.customer_id = c.customer_id;

$function$;


COMMENT ON FUNCTION
    public.customer_spending_totals(date)
IS
    'Shared customer-grain spending calculation. '
    'Includes every current customer, with zero totals '
    'for customers without eligible activity. '
    'Unattributed orders are excluded from customer output. '
    'Recorded history refers to available extract records, '
    'not complete lifetime customer spending.';


-- =====================================================
-- 2. Full-population customer ranking
-- =====================================================

\echo === 2. Full-population ranking ===

CREATE OR REPLACE FUNCTION public.customer_spending_ranked(
    p_as_of_date date,
    p_ranking_basis text DEFAULT 'trailing_12_months'
)
RETURNS TABLE (
    as_of_date date,
    ranking_basis text,
    window_start date,
    is_partial_month boolean,
    ranking_position bigint,
    spending_rank bigint,
    customer_id integer,
    full_name text,
    ranking_spending numeric,
    ranking_order_count bigint,
    window_spending numeric,
    window_order_count bigint,
    recorded_history_spending numeric,
    recorded_history_order_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $function$
BEGIN

    -- Reject invalid or missing ranking definitions.

    IF p_ranking_basis IS NULL
       OR p_ranking_basis NOT IN (
           'trailing_12_months',
           'recorded_history'
       )
    THEN
        RAISE EXCEPTION
            'Unsupported ranking basis: %',
            p_ranking_basis
        USING
            ERRCODE = '22023',
            HINT = 'Use trailing_12_months or recorded_history.';
    END IF;

    -- A missing reporting date produces no records.

    IF p_as_of_date IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY

    WITH selected_basis AS (
        SELECT
            t.*,

            CASE p_ranking_basis
                WHEN 'trailing_12_months'
                    THEN t.window_spending
                WHEN 'recorded_history'
                    THEN t.recorded_history_spending
            END AS selected_spending,

            CASE p_ranking_basis
                WHEN 'trailing_12_months'
                    THEN t.window_order_count
                WHEN 'recorded_history'
                    THEN t.recorded_history_order_count
            END AS selected_order_count

        FROM public.customer_spending_totals(
            p_as_of_date
        ) t
    ),

    candidates AS (
        SELECT s.*
        FROM selected_basis s
        WHERE s.selected_spending > 0
    ),

    ranked AS (
        SELECT
            c.*,

            ROW_NUMBER() OVER (
                ORDER BY
                    c.selected_spending DESC,
                    c.customer_id ASC
            ) AS calculated_position,

            RANK() OVER (
                ORDER BY c.selected_spending DESC
            ) AS calculated_rank

        FROM candidates c
    )

    SELECT
        r.as_of_date,
        p_ranking_basis,
        r.window_start,
        r.is_partial_month,

        r.calculated_position,
        r.calculated_rank,

        r.customer_id,
        r.full_name,

        r.selected_spending,
        r.selected_order_count,

        r.window_spending,
        r.window_order_count,

        r.recorded_history_spending,
        r.recorded_history_order_count

    FROM ranked r;

END;
$function$;


COMMENT ON FUNCTION
    public.customer_spending_ranked(date, text)
IS
    'Ranks the complete positive-spending candidate '
    'population using exact numeric spending. '
    'ROW_NUMBER uses ascending customer ID as an '
    'arbitrary deterministic tie-breaker. '
    'RANK preserves equal spending positions. '
    'Unsupported or NULL ranking bases are rejected.';


-- =====================================================
-- 3. Public top-100 reporting interface
-- =====================================================

\echo === 3. Top-100 customer report ===

CREATE OR REPLACE FUNCTION public.customer_top100(
    p_as_of_date date,
    p_ranking_basis text DEFAULT 'trailing_12_months'
)
RETURNS TABLE (
    as_of_date date,
    ranking_basis text,
    window_start date,
    is_partial_month boolean,
    ranking_position bigint,
    spending_rank bigint,
    customer_id integer,
    full_name text,
    ranking_spending numeric,
    ranking_order_count bigint,
    window_spending numeric,
    window_order_count bigint,
    recorded_history_spending numeric,
    recorded_history_order_count bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $function$

    SELECT r.*
    FROM public.customer_spending_ranked(
        p_as_of_date,
        p_ranking_basis
    ) r

    WHERE r.ranking_position <= 100

    ORDER BY r.ranking_position;

$function$;


COMMENT ON FUNCTION
    public.customer_top100(date, text)
IS
    'Returns up to 100 positive-spending customers. '
    'Defaults to trailing twelve-month spending. '
    'Recorded-history ranking is also supported. '
    'Use customer_top100_metadata to inspect '
    'cutoff ties and excluded customers.';


-- =====================================================
-- 4. Ranking metadata and cutoff transparency
-- =====================================================

\echo === 4. Top-100 cutoff metadata ===

CREATE OR REPLACE FUNCTION public.customer_top100_metadata(
    p_as_of_date date,
    p_ranking_basis text DEFAULT 'trailing_12_months'
)
RETURNS TABLE (
    as_of_date date,
    ranking_basis text,
    window_start date,
    is_partial_month boolean,
    qualifying_customer_count bigint,
    selected_customer_count bigint,
    cutoff_spending numeric,
    customers_at_cutoff bigint,
    cutoff_customers_selected bigint,
    cutoff_customers_excluded bigint,
    has_excluded_cutoff_ties boolean,
    qualifying_spending numeric,
    selected_spending numeric,
    remaining_qualifying_spending numeric,
    selected_spending_pct numeric,
    tie_break_policy text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $function$

    WITH ranked AS MATERIALIZED (
        SELECT r.*
        FROM public.customer_spending_ranked(
            p_as_of_date,
            p_ranking_basis
        ) r
    ),

    population AS (
        SELECT
            COUNT(*) AS qualifying_count,

            COUNT(*) FILTER (
                WHERE r.ranking_position <= 100
            ) AS selected_count,

            MAX(r.ranking_spending) FILTER (
                WHERE r.ranking_position = 100
            ) AS cutoff_amount,

            COALESCE(
                SUM(r.ranking_spending),
                0::numeric
            ) AS total_amount,

            COALESCE(
                SUM(r.ranking_spending) FILTER (
                    WHERE r.ranking_position <= 100
                ),
                0::numeric
            ) AS selected_amount

        FROM ranked r
    ),

    cutoff_details AS (
        SELECT
            COUNT(*) FILTER (
                WHERE r.ranking_spending = p.cutoff_amount
            ) AS at_cutoff,

            COUNT(*) FILTER (
                WHERE r.ranking_spending = p.cutoff_amount
                  AND r.ranking_position <= 100
            ) AS cutoff_selected,

            COUNT(*) FILTER (
                WHERE r.ranking_spending = p.cutoff_amount
                  AND r.ranking_position > 100
            ) AS cutoff_excluded

        FROM ranked r
        CROSS JOIN population p
    )

    SELECT
        p_as_of_date,
        p_ranking_basis,
        m.window_start,
        m.is_partial_month,

        p.qualifying_count,
        p.selected_count,
        p.cutoff_amount,

        d.at_cutoff,
        d.cutoff_selected,
        d.cutoff_excluded,

        d.cutoff_excluded > 0,

        p.total_amount,
        p.selected_amount,

        p.total_amount - p.selected_amount,

        ROUND(
            100.0 * p.selected_amount
            / NULLIF(p.total_amount, 0),
            4
        ),

        'Customer ID ascending; arbitrary deterministic tie-breaker'
            ::text

    FROM population p

    CROSS JOIN cutoff_details d

    CROSS JOIN public.monthly_reporting_metadata(
        p_as_of_date
    ) m;

$function$;


COMMENT ON FUNCTION
    public.customer_top100_metadata(date, text)
IS
    'Reports ranking population, spending concentration '
    'and cutoff tie exclusions. '
    'Cutoff spending is NULL when fewer than 100 '
    'customers qualify. '
    'Remaining qualifying spending excludes non-positive '
    'customers and unattributed orders. '
    'Percentage rounding occurs after ranking.';


COMMIT;

\echo === Customer ranking deployment completed ===
