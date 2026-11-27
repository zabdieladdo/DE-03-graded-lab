
-- DE-03: Kloud Kart
-- Stage 04.6: Ranking functional inspection
-- Evidence: E046a

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_ranking_inspection';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


-- =====================================================
-- 1. Shared calculation population
-- =====================================================

\echo === 1. Shared customer spending reconciliation ===

SELECT
    as_of_date,
    COUNT(*) AS customer_count,

    SUM(recorded_history_order_count)
        AS history_orders,

    SUM(opening_order_count)
        AS opening_orders,

    SUM(window_order_count)
        AS window_orders,

    SUM(recorded_history_spending)
        AS history_spending,

    SUM(opening_spending)
        AS opening_spending,

    SUM(window_spending)
        AS window_spending,

    COUNT(*) FILTER (
        WHERE recorded_history_spending
            IS DISTINCT FROM
            opening_spending + window_spending
    ) AS spending_identity_failures,

    COUNT(*) FILTER (
        WHERE recorded_history_order_count
            IS DISTINCT FROM
            opening_order_count + window_order_count
    ) AS count_identity_failures

FROM public.customer_spending_totals(
    DATE '2026-08-31'
)

GROUP BY as_of_date;


-- =====================================================
-- 2. Known customer examples
-- =====================================================

\echo === 2. Shared totals for known customers ===

SELECT
    customer_id,
    recorded_history_spending,
    recorded_history_order_count,
    opening_spending,
    opening_order_count,
    window_spending,
    window_order_count

FROM public.customer_spending_totals(
    DATE '2026-08-31'
)

WHERE customer_id IN (
    100001,
    100014,
    101702
)

ORDER BY customer_id;


-- =====================================================
-- 3. Headline top ten
-- =====================================================

\echo === 3A. Window ranking - top ten ===

SELECT
    ranking_position,
    spending_rank,
    customer_id,
    ranking_spending,
    ranking_order_count,
    recorded_history_spending

FROM public.customer_top100(
    DATE '2026-08-31'
)

ORDER BY ranking_position
LIMIT 10;


\echo === 3B. Recorded-history ranking - top ten ===

SELECT
    ranking_position,
    spending_rank,
    customer_id,
    ranking_spending,
    ranking_order_count,
    window_spending

FROM public.customer_top100(
    DATE '2026-08-31',
    'recorded_history'
)

ORDER BY ranking_position
LIMIT 10;


-- =====================================================
-- 4. All four ranking metadata scenarios
-- =====================================================

\echo === 4. Ranking metadata across both dates and bases ===

WITH scenarios AS (
    SELECT *
    FROM (
        VALUES
            (
                DATE '2026-08-31',
                'trailing_12_months'
            ),
            (
                DATE '2026-08-31',
                'recorded_history'
            ),
            (
                DATE '2026-11-26',
                'trailing_12_months'
            ),
            (
                DATE '2026-11-26',
                'recorded_history'
            )
    ) s(as_of_date, ranking_basis)
)

SELECT
    m.as_of_date,
    m.ranking_basis,
    m.qualifying_customer_count,
    m.selected_customer_count,
    m.cutoff_spending,
    m.customers_at_cutoff,
    m.cutoff_customers_selected,
    m.cutoff_customers_excluded,
    m.has_excluded_cutoff_ties,
    m.selected_spending,
    m.selected_spending_pct

FROM scenarios s

CROSS JOIN LATERAL
    public.customer_top100_metadata(
        s.as_of_date,
        s.ranking_basis
    ) m

ORDER BY
    m.as_of_date,
    m.ranking_basis;


-- =====================================================
-- 5. Distinct spending values within top 100
-- =====================================================

\echo === 5. Top-100 uniqueness and internal ties ===

WITH scenarios AS (
    SELECT *
    FROM (
        VALUES
            (
                DATE '2026-08-31',
                'trailing_12_months'
            ),
            (
                DATE '2026-08-31',
                'recorded_history'
            ),
            (
                DATE '2026-11-26',
                'trailing_12_months'
            ),
            (
                DATE '2026-11-26',
                'recorded_history'
            )
    ) s(as_of_date, ranking_basis)
)

SELECT
    r.as_of_date,
    r.ranking_basis,

    COUNT(*) AS selected_rows,

    COUNT(DISTINCT r.customer_id)
        AS distinct_customers,

    COUNT(DISTINCT r.ranking_position)
        AS distinct_positions,

    COUNT(DISTINCT r.ranking_spending)
        AS distinct_spending_amounts,

    COUNT(*) - COUNT(DISTINCT r.ranking_spending)
        AS repeated_spending_amounts,

    SUM(r.ranking_spending)
        AS selected_spending

FROM scenarios s

CROSS JOIN LATERAL
    public.customer_top100(
        s.as_of_date,
        s.ranking_basis
    ) r

GROUP BY
    r.as_of_date,
    r.ranking_basis

ORDER BY
    r.as_of_date,
    r.ranking_basis;


-- =====================================================
-- 6. Empty reporting period
-- =====================================================

\echo === 6A. Empty ranking ===

SELECT COUNT(*) AS selected_customers
FROM public.customer_top100(
    DATE '2025-01-31'
);


\echo === 6B. Empty ranking metadata ===

SELECT
    as_of_date,
    ranking_basis,
    qualifying_customer_count,
    selected_customer_count,
    cutoff_spending,
    customers_at_cutoff,
    cutoff_customers_excluded,
    has_excluded_cutoff_ties,
    qualifying_spending,
    selected_spending,
    selected_spending_pct

FROM public.customer_top100_metadata(
    DATE '2025-01-31'
);


ROLLBACK;

\echo === Customer ranking inspection completed ===
