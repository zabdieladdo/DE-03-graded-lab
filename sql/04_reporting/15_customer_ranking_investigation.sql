
-- DE-03: Kloud Kart
-- Stage 04.6: Customer ranking investigation
-- Decision: D031
-- Evidence: E045

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


-- =====================================================
-- 1. Compare ranking populations and financial coverage
-- =====================================================

\echo === 1. Ranking population and spending ===

WITH dates AS (
    SELECT
        d.as_of_date,
        (
            DATE_TRUNC('month', d.as_of_date::timestamp)
            - INTERVAL '11 months'
        )::date AS window_start
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)
),

activity AS (
    SELECT
        d.as_of_date,
        o.customer_id,

        COUNT(*) AS history_orders,
        SUM(o.total_amount) AS history_spending,

        COUNT(*) FILTER (
            WHERE o.order_date >= d.window_start
        ) AS window_orders,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date >= d.window_start
            ),
            0::numeric
        ) AS window_spending

    FROM dates d

    JOIN public.orders o
        ON o.order_date <
            d.as_of_date + INTERVAL '1 day'

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')

    GROUP BY
        d.as_of_date,
        o.customer_id
)

SELECT
    d.as_of_date,

    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE a.history_orders > 0
    ) AS history_purchasers,

    COUNT(*) FILTER (
        WHERE a.window_orders > 0
    ) AS window_purchasers,

    COUNT(*) FILTER (
        WHERE a.history_spending > 0
    ) AS positive_history_customers,

    COUNT(*) FILTER (
        WHERE a.window_spending > 0
    ) AS positive_window_customers,

    COUNT(*) FILTER (
        WHERE a.history_orders > 0
          AND a.history_spending = 0
    ) AS zero_value_history_purchasers,

    COUNT(*) FILTER (
        WHERE a.window_orders > 0
          AND a.window_spending = 0
    ) AS zero_value_window_purchasers,

    COUNT(*) FILTER (
        WHERE a.history_spending < 0
    ) AS negative_history_customers,

    COUNT(*) FILTER (
        WHERE a.window_spending < 0
    ) AS negative_window_customers,

    SUM(a.history_spending) AS history_spending,
    SUM(a.window_spending) AS window_spending

FROM dates d

CROSS JOIN public.customers c

LEFT JOIN activity a
    ON a.as_of_date = d.as_of_date
   AND a.customer_id = c.customer_id

GROUP BY d.as_of_date
ORDER BY d.as_of_date;


-- =====================================================
-- 2. Ranking boundary, ties and spending concentration
-- =====================================================

\echo === 2. Ranking boundary and concentration ===

WITH dates AS (
    SELECT
        d.as_of_date,
        (
            DATE_TRUNC('month', d.as_of_date::timestamp)
            - INTERVAL '11 months'
        )::date AS window_start
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)
),

activity AS (
    SELECT
        d.as_of_date,
        o.customer_id,
        SUM(o.total_amount) AS history_spending,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date >= d.window_start
            ),
            0::numeric
        ) AS window_spending

    FROM dates d

    JOIN public.orders o
        ON o.order_date <
            d.as_of_date + INTERVAL '1 day'

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')

    GROUP BY
        d.as_of_date,
        o.customer_id
),

candidates AS (
    SELECT
        a.as_of_date,
        a.customer_id,
        b.ranking_basis,
        b.spending

    FROM activity a

    CROSS JOIN LATERAL (
        VALUES
            ('recorded_history', a.history_spending),
            ('trailing_12_months', a.window_spending)
    ) b(ranking_basis, spending)

    WHERE b.spending > 0
),

ranked AS (
    SELECT
        c.*,

        ROW_NUMBER() OVER (
            PARTITION BY as_of_date, ranking_basis
            ORDER BY spending DESC, customer_id
        ) AS row_position,

        RANK() OVER (
            PARTITION BY as_of_date, ranking_basis
            ORDER BY spending DESC
        ) AS spending_rank,

        DENSE_RANK() OVER (
            PARTITION BY as_of_date, ranking_basis
            ORDER BY spending DESC
        ) AS dense_spending_rank

    FROM candidates c
),

boundary AS (
    SELECT
        as_of_date,
        ranking_basis,
        spending AS cutoff_spending
    FROM ranked
    WHERE row_position = 100
)

SELECT
    r.as_of_date,
    r.ranking_basis,

    COUNT(*) AS qualifying_customers,

    COUNT(*) FILTER (
        WHERE row_position <= 100
    ) AS row_number_top100,

    COUNT(*) FILTER (
        WHERE spending_rank <= 100
    ) AS rank_top100,

    COUNT(*) FILTER (
        WHERE dense_spending_rank <= 100
    ) AS dense_rank_top100,

    MAX(r.spending) AS highest_spending,

    MAX(b.cutoff_spending) AS rank100_spending,

    MAX(r.spending) FILTER (
        WHERE row_position = 101
    ) AS rank101_spending,

    COUNT(*) FILTER (
        WHERE r.spending = b.cutoff_spending
    ) AS customers_at_cutoff,

    COUNT(*) FILTER (
        WHERE r.spending = b.cutoff_spending
          AND row_position > 100
    ) AS tied_customers_excluded,

    SUM(r.spending) FILTER (
        WHERE row_position <= 100
    ) AS top100_spending,

    SUM(r.spending) AS qualifying_spending,

    ROUND(
        100.0
        * SUM(r.spending) FILTER (
            WHERE row_position <= 100
        )
        / NULLIF(SUM(r.spending), 0),
        4
    ) AS top100_spending_pct

FROM ranked r

LEFT JOIN boundary b
    ON b.as_of_date = r.as_of_date
   AND b.ranking_basis = r.ranking_basis

GROUP BY
    r.as_of_date,
    r.ranking_basis

ORDER BY
    r.as_of_date,
    r.ranking_basis;


-- =====================================================
-- 3. Ranking-period membership and position changes
-- =====================================================

\echo === 3. Ranking period sensitivity ===

WITH dates AS (
    SELECT
        d.as_of_date,
        (
            DATE_TRUNC('month', d.as_of_date::timestamp)
            - INTERVAL '11 months'
        )::date AS window_start
    FROM (
        VALUES
            (DATE '2026-08-31'),
            (DATE '2026-11-26')
    ) d(as_of_date)
),

activity AS (
    SELECT
        d.as_of_date,
        o.customer_id,

        SUM(o.total_amount) AS history_spending,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date >= d.window_start
            ),
            0::numeric
        ) AS window_spending

    FROM dates d

    JOIN public.orders o
        ON o.order_date <
            d.as_of_date + INTERVAL '1 day'

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')

    GROUP BY
        d.as_of_date,
        o.customer_id
),

history_ranked AS (
    SELECT
        a.*,

        ROW_NUMBER() OVER (
            PARTITION BY as_of_date
            ORDER BY history_spending DESC, customer_id
        ) AS position

    FROM activity a
    WHERE history_spending > 0
),

window_ranked AS (
    SELECT
        a.*,

        ROW_NUMBER() OVER (
            PARTITION BY as_of_date
            ORDER BY window_spending DESC, customer_id
        ) AS position

    FROM activity a
    WHERE window_spending > 0
),

membership AS (
    SELECT
        as_of_date,
        customer_id,
        position AS history_position,
        NULL::bigint AS window_position
    FROM history_ranked
    WHERE position <= 100

    UNION ALL

    SELECT
        as_of_date,
        customer_id,
        NULL::bigint,
        position
    FROM window_ranked
    WHERE position <= 100
),

combined AS (
    SELECT
        as_of_date,
        customer_id,
        MAX(history_position) AS history_position,
        MAX(window_position) AS window_position
    FROM membership
    GROUP BY
        as_of_date,
        customer_id
)

SELECT
    as_of_date,

    COUNT(history_position) AS history_top100,

    COUNT(window_position) AS window_top100,

    COUNT(*) FILTER (
        WHERE history_position IS NOT NULL
          AND window_position IS NOT NULL
    ) AS retained_customers,

    COUNT(*) FILTER (
        WHERE history_position IS NOT NULL
          AND window_position IS NULL
    ) AS history_only,

    COUNT(*) FILTER (
        WHERE history_position IS NULL
          AND window_position IS NOT NULL
    ) AS window_only,

    COUNT(*) FILTER (
        WHERE history_position = window_position
    ) AS unchanged_positions,

    COUNT(*) FILTER (
        WHERE history_position IS NOT NULL
          AND window_position IS NOT NULL
          AND history_position <> window_position
    ) AS changed_positions,

    ROUND(
        AVG(ABS(history_position - window_position)),
        2
    ) AS mean_absolute_rank_change,

    MAX(
        ABS(history_position - window_position)
    ) AS largest_rank_change

FROM combined

GROUP BY as_of_date
ORDER BY as_of_date;


-- =====================================================
-- 4. Inspect the headline top ten under each basis
-- =====================================================

\echo === 4. Headline top ten comparison ===

WITH activity AS (
    SELECT
        o.customer_id,

        SUM(o.total_amount) AS history_spending,

        COALESCE(
            SUM(o.total_amount) FILTER (
                WHERE o.order_date >= DATE '2025-09-01'
            ),
            0::numeric
        ) AS window_spending

    FROM public.orders o

    JOIN public.customers c
        ON c.customer_id = o.customer_id

    WHERE LOWER(BTRIM(o.status))
        IN ('completed', 'complete')

      AND o.order_date < DATE '2026-09-01'

    GROUP BY o.customer_id
),

candidates AS (
    SELECT
        a.customer_id,
        a.history_spending,
        a.window_spending,
        b.ranking_basis,
        b.spending

    FROM activity a

    CROSS JOIN LATERAL (
        VALUES
            ('recorded_history', a.history_spending),
            ('trailing_12_months', a.window_spending)
    ) b(ranking_basis, spending)

    WHERE b.spending > 0
),

ranked AS (
    SELECT
        c.*,

        ROW_NUMBER() OVER (
            PARTITION BY ranking_basis
            ORDER BY spending DESC, customer_id
        ) AS position

    FROM candidates c
)

SELECT
    ranking_basis,
    position,
    customer_id,
    spending AS ranking_spending,
    history_spending,
    window_spending,
    history_spending - window_spending
        AS opening_spending

FROM ranked

WHERE position <= 10

ORDER BY
    ranking_basis,
    position;


ROLLBACK;

\echo === Customer ranking investigation completed ===
