-- DE-03: Status and spending eligibility sensitivity analysis
--
-- Purpose:
-- Measure the effects of six alternative reporting policies.
-- No historical records are modified.
--
-- Assumptions:
-- 1. All available order history is included.
-- 2. orders.total_amount is the recorded spending measure.
-- 3. Unattributed orders are disclosed separately.
-- 4. All existing customers are included, including zero spenders.
-- 5. Ranking ties are resolved deterministically by customer_id.
-- 6. No candidate policy represents approved revenue recognition.

\set ON_ERROR_STOP on
\pset pager off
\pset format unaligned
\pset fieldsep '|'

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo '=== Database identity ==='

SELECT
    current_database() AS database_name,
    current_setting('transaction_isolation') AS isolation_level;

\echo '=== Scenario sensitivity comparison ==='

WITH scenarios (
    scenario_id,
    vocabulary,
    eligibility
) AS (
    VALUES
        ('S1', 'exact', 'completed'),
        ('S2', 'normalized', 'completed'),
        ('S3', 'exact', 'completed_shipped'),
        ('S4', 'normalized', 'completed_shipped'),
        ('S5', 'exact', 'exclude_cancelled_refunded'),
        ('S6', 'normalized', 'exclude_cancelled_refunded')
),

-- Preserve raw values and calculate a candidate mapping.

order_base AS (
    SELECT
        order_id,
        customer_id,
        total_amount,
        status AS raw_status,
        CASE LOWER(TRIM(status))
            WHEN 'complete' THEN 'completed'
            WHEN 'canceled' THEN 'cancelled'
            ELSE LOWER(TRIM(status))
        END AS normalized_status
    FROM orders
),

-- Evaluate every order under all six scenarios.

scenario_orders AS (
    SELECT
        s.scenario_id,
        s.eligibility,
        o.order_id,
        o.customer_id,
        o.total_amount,
        CASE
            WHEN s.vocabulary = 'exact'
                THEN o.raw_status
            ELSE o.normalized_status
        END AS effective_status
    FROM scenarios AS s
    CROSS JOIN order_base AS o
),

-- Apply the alternative spending eligibility rules.

eligible_orders AS (
    SELECT
        scenario_id,
        order_id,
        customer_id,
        total_amount
    FROM scenario_orders
    WHERE
        (
            eligibility = 'completed'
            AND effective_status = 'completed'
        )
        OR
        (
            eligibility = 'completed_shipped'
            AND effective_status IN ('completed', 'shipped')
        )
        OR
        (
            eligibility = 'exclude_cancelled_refunded'
            AND effective_status NOT IN ('cancelled', 'refunded')
        )
),

-- Reconcile eligible amounts before customer attribution.

scenario_totals AS (
    SELECT
        e.scenario_id,
        COUNT(*) AS eligible_order_count,
        SUM(e.total_amount) AS eligible_order_amount,
        COUNT(*) FILTER (
            WHERE c.customer_id IS NULL
        ) AS unattributed_orders,
        COALESCE(
            SUM(e.total_amount) FILTER (
                WHERE c.customer_id IS NULL
            ),
            0
        ) AS unattributed_amount
    FROM eligible_orders AS e
    LEFT JOIN customers AS c
        ON e.customer_id = c.customer_id
    GROUP BY e.scenario_id
),

-- Aggregate spending before joining to the customer population.

customer_aggregates AS (
    SELECT
        scenario_id,
        customer_id,
        COUNT(*) AS eligible_order_count,
        SUM(total_amount) AS total_spent
    FROM eligible_orders
    GROUP BY
        scenario_id,
        customer_id
),

-- Include every existing customer in every scenario.

customer_spending AS (
    SELECT
        s.scenario_id,
        c.customer_id,
        COALESCE(a.eligible_order_count, 0) AS order_count,
        COALESCE(a.total_spent, 0) AS total_spent
    FROM scenarios AS s
    CROSS JOIN customers AS c
    LEFT JOIN customer_aggregates AS a
        ON a.scenario_id = s.scenario_id
        AND a.customer_id = c.customer_id
),

-- Keep the ranking rule constant across scenarios.

ranked_customers AS (
    SELECT
        scenario_id,
        customer_id,
        order_count,
        total_spent,
        ROW_NUMBER() OVER (
            PARTITION BY scenario_id
            ORDER BY
                total_spent DESC,
                customer_id
        ) AS customer_rank
    FROM customer_spending
),

-- Summarize spending and the top 100 in each scenario.

customer_summary AS (
    SELECT
        scenario_id,
        COUNT(*) AS customer_population,
        COUNT(*) FILTER (
            WHERE order_count > 0
        ) AS customers_with_orders,
        SUM(total_spent) AS attributed_spending,
        SUM(total_spent) FILTER (
            WHERE customer_rank <= 100
        ) AS top_100_spending
    FROM ranked_customers
    GROUP BY scenario_id
),

-- Baseline comparisons and isolated decision effects.

comparison_pairs (
    comparison_id,
    reference_scenario,
    alternative_scenario,
    comparison_purpose
) AS (
    VALUES
        (1, 'S1', 'S1', 'Baseline control'),
        (2, 'S1', 'S2', 'Vocabulary: completed only'),
        (3, 'S1', 'S3', 'Eligibility: exact vocabulary'),
        (4, 'S1', 'S4', 'Combined: completed and shipped'),
        (5, 'S1', 'S5', 'Broad eligibility: exact'),
        (6, 'S1', 'S6', 'Combined: broad eligibility'),
        (7, 'S3', 'S4', 'Vocabulary: completed and shipped'),
        (8, 'S5', 'S6', 'Vocabulary: broad eligibility'),
        (9, 'S2', 'S4', 'Eligibility: normalized shipped'),
        (10, 'S2', 'S6', 'Eligibility: normalized broad'),
        (11, 'S4', 'S6', 'Eligibility: normalized pending')
),

-- Compare the same customer across each scenario pair.

customer_changes AS (
    SELECT
        p.comparison_id,
        a.customer_id,
        a.total_spent AS reference_spending,
        b.total_spent AS alternative_spending,
        a.customer_rank AS reference_rank,
        b.customer_rank AS alternative_rank
    FROM comparison_pairs AS p
    JOIN ranked_customers AS a
        ON a.scenario_id = p.reference_scenario
    JOIN ranked_customers AS b
        ON b.scenario_id = p.alternative_scenario
        AND b.customer_id = a.customer_id
),

comparison_summary AS (
    SELECT
        comparison_id,

        COUNT(*) FILTER (
            WHERE reference_spending <> alternative_spending
        ) AS customers_with_changed_spending,

        SUM(
            ABS(alternative_spending - reference_spending)
        ) AS absolute_customer_spending_change,

        MAX(
            ABS(alternative_spending - reference_spending)
        ) AS largest_customer_spending_change,

        COUNT(*) FILTER (
            WHERE reference_rank <= 100
                AND alternative_rank <= 100
        ) AS top_100_overlap,

        COUNT(*) FILTER (
            WHERE reference_rank > 100
                AND alternative_rank <= 100
        ) AS top_100_entrants,

        COUNT(*) FILTER (
            WHERE reference_rank <= 100
                AND alternative_rank > 100
        ) AS top_100_exits,

        ROUND(
            AVG(
                ABS(alternative_rank - reference_rank)
            ) FILTER (
                WHERE reference_rank <= 100
                    AND alternative_rank <= 100
            ),
            2
        ) AS avg_shared_top_100_rank_movement

    FROM customer_changes
    GROUP BY comparison_id
)

SELECT
    p.comparison_id,
    p.reference_scenario,
    p.alternative_scenario,
    p.comparison_purpose,

    st.eligible_order_count,
    st.eligible_order_amount,
    st.unattributed_orders,
    st.unattributed_amount,

    alt.customers_with_orders,
    alt.attributed_spending,

    alt.attributed_spending
        - ref.attributed_spending AS spending_delta,

    ROUND(
        100.0 * (
            alt.attributed_spending - ref.attributed_spending
        ) / NULLIF(ref.attributed_spending, 0),
        2
    ) AS spending_change_pct,

    cs.customers_with_changed_spending,
    cs.absolute_customer_spending_change,
    cs.largest_customer_spending_change,

    cs.top_100_overlap,
    cs.top_100_entrants,
    cs.top_100_exits,
    cs.avg_shared_top_100_rank_movement,

    alt.top_100_spending,

    alt.top_100_spending
        - ref.top_100_spending AS top_100_spending_delta,

    st.eligible_order_amount
        - st.unattributed_amount
        - alt.attributed_spending AS reconciliation_difference

FROM comparison_pairs AS p
JOIN comparison_summary AS cs
    ON cs.comparison_id = p.comparison_id
JOIN customer_summary AS ref
    ON ref.scenario_id = p.reference_scenario
JOIN customer_summary AS alt
    ON alt.scenario_id = p.alternative_scenario
JOIN scenario_totals AS st
    ON st.scenario_id = p.alternative_scenario
ORDER BY p.comparison_id;

ROLLBACK;