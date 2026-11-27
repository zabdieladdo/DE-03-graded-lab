
-- DE-03: Kloud Kart
-- Stage 04.6: Customer ranking verification
-- Decision: D031
-- Evidence: E047

\set ON_ERROR_STOP on
\pset pager off
\timing on


-- =====================================================
-- PART A: Independent read-only baseline verification
-- =====================================================

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_ranking_verification';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


\echo === A. Independent baseline verification ===

DO $test$
DECLARE
    v_date date;
    v_basis text;
    v_start date;

    v_expected record;
    v_actual record;

    v_top_count bigint;
    v_top_amount numeric;
    v_attributed numeric;
    v_unattributed numeric;
    v_eligible numeric;

BEGIN

    FOREACH v_date IN ARRAY ARRAY[
        DATE '2026-08-31',
        DATE '2026-11-26'
    ]
    LOOP

        v_start := (
            DATE_TRUNC('month', v_date::timestamp)
            - INTERVAL '11 months'
        )::date;


        -- ---------------------------------------------
        -- A01: Independently reconstruct all totals
        -- ---------------------------------------------

        IF EXISTS (

            WITH raw_activity AS MATERIALIZED (
                SELECT
                    o.customer_id,

                    SUM(o.total_amount) AS history_amount,
                    COUNT(*) AS history_count,

                    SUM(o.total_amount) FILTER (
                        WHERE o.order_date < v_start
                    ) AS opening_amount,

                    COUNT(*) FILTER (
                        WHERE o.order_date < v_start
                    ) AS opening_count,

                    SUM(o.total_amount) FILTER (
                        WHERE o.order_date >= v_start
                    ) AS window_amount,

                    COUNT(*) FILTER (
                        WHERE o.order_date >= v_start
                    ) AS window_count

                FROM public.orders o

                WHERE LOWER(BTRIM(o.status))
                    IN ('completed', 'complete')

                  AND o.order_date
                    < v_date + INTERVAL '1 day'

                GROUP BY o.customer_id
            ),

            expected AS MATERIALIZED (
                SELECT
                    v_date AS as_of_date,
                    v_start AS window_start,

                    EXTRACT(DAY FROM v_date + 1) <> 1
                        AS is_partial_month,

                    c.customer_id,
                    c.full_name,

                    COALESCE(a.history_amount, 0::numeric),
                    COALESCE(a.history_count, 0::bigint),

                    COALESCE(a.opening_amount, 0::numeric),
                    COALESCE(a.opening_count, 0::bigint),

                    COALESCE(a.window_amount, 0::numeric),
                    COALESCE(a.window_count, 0::bigint)

                FROM public.customers c

                LEFT JOIN raw_activity a
                    ON a.customer_id = c.customer_id
            ),

            actual AS MATERIALIZED (
                SELECT *
                FROM public.customer_spending_totals(v_date)
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'A01 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A01: Independent shared totals match (%)',
            v_date;


        -- ---------------------------------------------
        -- A02: Coverage and partition identities
        -- ---------------------------------------------

        SELECT
            COUNT(*) AS customer_count,
            COUNT(DISTINCT t.customer_id) AS distinct_count,

            COUNT(*) FILTER (
                WHERE t.recorded_history_spending
                    IS DISTINCT FROM
                    t.opening_spending + t.window_spending

                   OR t.recorded_history_order_count
                    IS DISTINCT FROM
                    t.opening_order_count + t.window_order_count
            ) AS failures

        INTO v_actual

        FROM public.customer_spending_totals(v_date) t;

        IF v_actual.customer_count <> 40420
           OR v_actual.distinct_count <> 40420
           OR v_actual.failures <> 0
        THEN
            RAISE EXCEPTION
                'A02 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A02: Coverage and partition identities (%)',
            v_date;


        -- ---------------------------------------------
        -- A03: D028 customer summary reconciliation
        -- ---------------------------------------------

        IF EXISTS (

            WITH expected AS MATERIALIZED (
                SELECT
                    s.customer_id,
                    s.total_spent,
                    s.order_count

                FROM public.customer_spending_summary(v_date) s
            ),

            actual AS MATERIALIZED (
                SELECT
                    t.customer_id,
                    t.recorded_history_spending,
                    t.recorded_history_order_count

                FROM public.customer_spending_totals(v_date) t
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'A03 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A03: D028 customer summary matches (%)',
            v_date;


        -- ---------------------------------------------
        -- A04: D029 monthly reconciliation
        -- ---------------------------------------------

        IF EXISTS (

            WITH expected AS MATERIALIZED (
                SELECT
                    m.customer_id,
                    SUM(m.monthly_spending),
                    SUM(m.monthly_order_count)::bigint

                FROM public.customer_monthly_spending(v_date) m

                GROUP BY m.customer_id
            ),

            actual AS MATERIALIZED (
                SELECT
                    t.customer_id,
                    t.window_spending,
                    t.window_order_count

                FROM public.customer_spending_totals(v_date) t
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'A04 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A04: D029 monthly totals match (%)',
            v_date;


        -- ---------------------------------------------
        -- A05: D030 cumulative balance reconciliation
        -- ---------------------------------------------

        IF EXISTS (

            WITH expected AS MATERIALIZED (
                SELECT
                    m.customer_id,
                    m.opening_spending,
                    m.window_cumulative_spending,
                    m.cumulative_since_extract_start

                FROM public.customer_monthly_running_spending(
                    v_date
                ) m

                WHERE m.order_month =
                    DATE_TRUNC('month', v_date::timestamp)::date
            ),

            actual AS MATERIALIZED (
                SELECT
                    t.customer_id,
                    t.opening_spending,
                    t.window_spending,
                    t.recorded_history_spending

                FROM public.customer_spending_totals(v_date) t
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'A05 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A05: D030 final cumulative balances match (%)',
            v_date;


        -- ---------------------------------------------
        -- Test both ranking definitions
        -- ---------------------------------------------

        FOREACH v_basis IN ARRAY ARRAY[
            'trailing_12_months',
            'recorded_history'
        ]
        LOOP

            -- -----------------------------------------
            -- A06: Independent exact ranking membership
            -- -----------------------------------------

            IF EXISTS (

                WITH raw_totals AS MATERIALIZED (
                    SELECT
                        c.customer_id,
                        c.full_name,

                        SUM(o.total_amount) AS history_amount,
                        COUNT(*) AS history_count,

                        COALESCE(
                            SUM(o.total_amount) FILTER (
                                WHERE o.order_date >= v_start
                            ),
                            0::numeric
                        ) AS window_amount,

                        COUNT(*) FILTER (
                            WHERE o.order_date >= v_start
                        ) AS window_count

                    FROM public.orders o

                    JOIN public.customers c
                        ON c.customer_id = o.customer_id

                    WHERE LOWER(BTRIM(o.status))
                        IN ('completed', 'complete')

                      AND o.order_date
                        < v_date + INTERVAL '1 day'

                    GROUP BY c.customer_id, c.full_name
                ),

                candidates AS (
                    SELECT
                        t.*,

                        CASE v_basis
                            WHEN 'recorded_history'
                                THEN t.history_amount
                            ELSE t.window_amount
                        END AS selected_amount,

                        CASE v_basis
                            WHEN 'recorded_history'
                                THEN t.history_count
                            ELSE t.window_count
                        END AS selected_count

                    FROM raw_totals t
                ),

                ranked AS (
                    SELECT
                        c.*,

                        ROW_NUMBER() OVER (
                            ORDER BY
                                c.selected_amount DESC,
                                c.customer_id
                        ) AS position,

                        RANK() OVER (
                            ORDER BY c.selected_amount DESC
                        ) AS amount_rank

                    FROM candidates c

                    WHERE c.selected_amount > 0
                ),

                expected AS MATERIALIZED (
                    SELECT
                        v_date,
                        v_basis,
                        v_start,

                        EXTRACT(DAY FROM v_date + 1) <> 1,

                        r.position,
                        r.amount_rank,

                        r.customer_id,
                        r.full_name,

                        r.selected_amount,
                        r.selected_count,

                        r.window_amount,
                        r.window_count,

                        r.history_amount,
                        r.history_count

                    FROM ranked r

                    WHERE r.position <= 100
                ),

                actual AS MATERIALIZED (
                    SELECT *
                    FROM public.customer_top100(
                        v_date,
                        v_basis
                    )
                )

                (
                    SELECT * FROM expected
                    EXCEPT ALL
                    SELECT * FROM actual
                )

                UNION ALL

                (
                    SELECT * FROM actual
                    EXCEPT ALL
                    SELECT * FROM expected
                )

            ) THEN
                RAISE EXCEPTION
                    'A06 failed for %, %',
                    v_date, v_basis;
            END IF;

            RAISE NOTICE
                'PASS A06: Exact ranking records match (%, %)',
                v_date, v_basis;


            -- -----------------------------------------
            -- A07: Ranking integrity and selection size
            -- -----------------------------------------

            SELECT
                COUNT(*) AS selected_count,
                COUNT(DISTINCT r.customer_id) AS distinct_ids,

                COUNT(DISTINCT r.ranking_position)
                    AS distinct_positions,

                MIN(r.ranking_position) AS first_position,
                MAX(r.ranking_position) AS last_position,

                COUNT(*) FILTER (
                    WHERE r.ranking_spending <= 0
                ) AS invalid_candidates,

                SUM(r.ranking_spending) AS selected_amount

            INTO v_actual

            FROM public.customer_top100(
                v_date,
                v_basis
            ) r;

            IF v_actual.selected_count <> 100
               OR v_actual.distinct_ids <> 100
               OR v_actual.distinct_positions <> 100
               OR v_actual.first_position <> 1
               OR v_actual.last_position <> 100
               OR v_actual.invalid_candidates <> 0
            THEN
                RAISE EXCEPTION
                    'A07 failed for %, %',
                    v_date, v_basis;
            END IF;

            v_top_count := v_actual.selected_count;
            v_top_amount := v_actual.selected_amount;

            RAISE NOTICE
                'PASS A07: Ranking integrity (%, %)',
                v_date, v_basis;


            -- -----------------------------------------
            -- A08: Independent financial reconciliation
            -- -----------------------------------------

            WITH raw_eligible AS MATERIALIZED (
                SELECT
                    o.customer_id,
                    o.total_amount

                FROM public.orders o

                WHERE LOWER(BTRIM(o.status))
                    IN ('completed', 'complete')

                  AND o.order_date
                    < v_date + INTERVAL '1 day'

                  AND (
                      v_basis = 'recorded_history'
                      OR o.order_date >= v_start
                  )
            )

            SELECT
                COALESCE(SUM(e.total_amount), 0),

                COALESCE(
                    SUM(e.total_amount) FILTER (
                        WHERE c.customer_id IS NOT NULL
                    ),
                    0
                ),

                COALESCE(
                    SUM(e.total_amount) FILTER (
                        WHERE c.customer_id IS NULL
                    ),
                    0
                )

            INTO
                v_eligible,
                v_attributed,
                v_unattributed

            FROM raw_eligible e

            LEFT JOIN public.customers c
                ON c.customer_id = e.customer_id;


            -- Reconstruct remaining customer spending
            -- directly from raw eligible orders.

            WITH selected AS MATERIALIZED (
                SELECT r.customer_id

                FROM public.customer_top100(
                    v_date,
                    v_basis
                ) r
            )

            SELECT
                COALESCE(
                    SUM(o.total_amount) FILTER (
                        WHERE s.customer_id IS NOT NULL
                    ),
                    0
                ) AS selected_amount,

                COALESCE(
                    SUM(o.total_amount) FILTER (
                        WHERE s.customer_id IS NULL
                    ),
                    0
                ) AS remaining_amount

            INTO v_expected

            FROM public.orders o

            JOIN public.customers c
                ON c.customer_id = o.customer_id

            LEFT JOIN selected s
                ON s.customer_id = c.customer_id

            WHERE LOWER(BTRIM(o.status))
                IN ('completed', 'complete')

              AND o.order_date
                < v_date + INTERVAL '1 day'

              AND (
                  v_basis = 'recorded_history'
                  OR o.order_date >= v_start
              );

            IF v_top_amount
                    IS DISTINCT FROM v_expected.selected_amount

               OR v_top_amount + v_expected.remaining_amount
                    IS DISTINCT FROM v_attributed

               OR v_top_amount
                    + v_expected.remaining_amount
                    + v_unattributed
                    IS DISTINCT FROM v_eligible
            THEN
                RAISE EXCEPTION
                    'A08 failed for %, %',
                    v_date, v_basis;
            END IF;

            RAISE NOTICE
                'PASS A08: Financial reconciliation (%, %): selected=%, remaining=%, unattributed=%, eligible=%',
                v_date,
                v_basis,
                v_top_amount,
                v_expected.remaining_amount,
                v_unattributed,
                v_eligible;


            -- -----------------------------------------
            -- A09: Independently reconstruct metadata
            -- -----------------------------------------

            WITH raw_totals AS (
                SELECT
                    o.customer_id,
                    SUM(o.total_amount) AS amount

                FROM public.orders o

                JOIN public.customers c
                    ON c.customer_id = o.customer_id

                WHERE LOWER(BTRIM(o.status))
                    IN ('completed', 'complete')

                  AND o.order_date
                    < v_date + INTERVAL '1 day'

                  AND (
                      v_basis = 'recorded_history'
                      OR o.order_date >= v_start
                  )

                GROUP BY o.customer_id
            ),

            ranked AS MATERIALIZED (
                SELECT
                    t.*,

                    ROW_NUMBER() OVER (
                        ORDER BY t.amount DESC, t.customer_id
                    ) AS position

                FROM raw_totals t

                WHERE t.amount > 0
            ),

            population AS (
                SELECT
                    COUNT(*) AS qualifying_count,

                    SUM(r.amount) AS qualifying_amount,

                    SUM(r.amount) FILTER (
                        WHERE r.position <= 100
                    ) AS selected_amount,

                    MAX(r.amount) FILTER (
                        WHERE r.position = 100
                    ) AS cutoff_amount

                FROM ranked r
            )

            SELECT
                p.*,

                (
                    SELECT COUNT(*)
                    FROM ranked r
                    WHERE r.amount = p.cutoff_amount
                ) AS cutoff_count,

                (
                    SELECT COUNT(*)
                    FROM ranked r
                    WHERE r.amount = p.cutoff_amount
                      AND r.position <= 100
                ) AS cutoff_selected,

                (
                    SELECT COUNT(*)
                    FROM ranked r
                    WHERE r.amount = p.cutoff_amount
                      AND r.position > 100
                ) AS cutoff_excluded

            INTO v_expected

            FROM population p;


            SELECT *
            INTO STRICT v_actual

            FROM public.customer_top100_metadata(
                v_date,
                v_basis
            );


            IF v_actual.as_of_date
                    IS DISTINCT FROM v_date

               OR v_actual.ranking_basis
                    IS DISTINCT FROM v_basis

               OR v_actual.window_start
                    IS DISTINCT FROM v_start

               OR v_actual.is_partial_month
                    IS DISTINCT FROM
                    (EXTRACT(DAY FROM v_date + 1) <> 1)

               OR v_actual.qualifying_customer_count
                    IS DISTINCT FROM v_expected.qualifying_count

               OR v_actual.selected_customer_count
                    IS DISTINCT FROM v_top_count

               OR v_actual.cutoff_spending
                    IS DISTINCT FROM v_expected.cutoff_amount

               OR v_actual.customers_at_cutoff
                    IS DISTINCT FROM v_expected.cutoff_count

               OR v_actual.cutoff_customers_selected
                    IS DISTINCT FROM v_expected.cutoff_selected

               OR v_actual.cutoff_customers_excluded
                    IS DISTINCT FROM v_expected.cutoff_excluded

               OR v_actual.has_excluded_cutoff_ties
                    IS DISTINCT FROM
                    (v_expected.cutoff_excluded > 0)

               OR v_actual.qualifying_spending
                    IS DISTINCT FROM v_expected.qualifying_amount

               OR v_actual.selected_spending
                    IS DISTINCT FROM v_top_amount

               OR v_actual.remaining_qualifying_spending
                    IS DISTINCT FROM
                    (
                        v_expected.qualifying_amount
                        - v_top_amount
                    )

               OR v_actual.selected_spending_pct
                    IS DISTINCT FROM
                    ROUND(
                        100.0 * v_top_amount
                        / NULLIF(v_expected.qualifying_amount, 0),
                        4
                    )

               OR v_actual.tie_break_policy
                    IS DISTINCT FROM
                    'Customer ID ascending; arbitrary deterministic tie-breaker'

            THEN
                RAISE EXCEPTION
                    'A09 failed for %, %',
                    v_date, v_basis;
            END IF;

            RAISE NOTICE
                'PASS A09: Independent metadata matches (%, %)',
                v_date, v_basis;

        END LOOP;


        -- ---------------------------------------------
        -- A10: Default basis equals explicit window
        -- ---------------------------------------------

        IF EXISTS (

            WITH implicit_basis AS MATERIALIZED (
                SELECT *
                FROM public.customer_top100(v_date)
            ),

            explicit_basis AS MATERIALIZED (
                SELECT *
                FROM public.customer_top100(
                    v_date,
                    'trailing_12_months'
                )
            )

            (
                SELECT * FROM implicit_basis
                EXCEPT ALL
                SELECT * FROM explicit_basis
            )

            UNION ALL

            (
                SELECT * FROM explicit_basis
                EXCEPT ALL
                SELECT * FROM implicit_basis
            )

        ) THEN
            RAISE EXCEPTION
                'A10 failed for %', v_date;
        END IF;

        RAISE NOTICE
            'PASS A10: Default ranking basis (%)',
            v_date;

    END LOOP;

END;
$test$;

ROLLBACK;


-- =====================================================
-- PART B: Transactional edge-case verification
-- =====================================================

\echo === B. Transactional edge-case verification ===

BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL application_name = 'de03_ranking_fixture_test';

DO $guard$
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN
        RAISE EXCEPTION 'Incorrect database';
    END IF;
END;
$guard$;


-- ---------------------------------------------
-- B01: Empty reporting population
-- ---------------------------------------------

DO $test$
DECLARE
    v_actual record;
    v_basis text;
BEGIN

    FOREACH v_basis IN ARRAY ARRAY[
        'trailing_12_months',
        'recorded_history'
    ]
    LOOP

        IF EXISTS (
            SELECT 1
            FROM public.customer_top100(
                DATE '2025-01-31',
                v_basis
            )
        ) THEN
            RAISE EXCEPTION
                'B01 failed: empty ranking';
        END IF;

        SELECT *
        INTO STRICT v_actual

        FROM public.customer_top100_metadata(
            DATE '2025-01-31',
            v_basis
        );

        IF v_actual.qualifying_customer_count <> 0
           OR v_actual.selected_customer_count <> 0
           OR v_actual.cutoff_spending IS NOT NULL
           OR v_actual.customers_at_cutoff <> 0
           OR v_actual.cutoff_customers_selected <> 0
           OR v_actual.cutoff_customers_excluded <> 0
           OR v_actual.has_excluded_cutoff_ties
           OR v_actual.qualifying_spending <> 0
           OR v_actual.selected_spending <> 0
           OR v_actual.remaining_qualifying_spending <> 0
           OR v_actual.selected_spending_pct IS NOT NULL
        THEN
            RAISE EXCEPTION
                'B01 failed: empty metadata';
        END IF;

        RAISE NOTICE
            'PASS B01: Empty population (%)', v_basis;

    END LOOP;

END;
$test$;


-- ---------------------------------------------
-- B02: Invalid and NULL parameter behaviour
-- ---------------------------------------------

DO $test$
BEGIN

    BEGIN
        PERFORM 1
        FROM public.customer_top100(
            DATE '2026-08-31',
            'invalid_basis'
        );

        RAISE EXCEPTION
            'B02 failed: invalid basis accepted';

    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            RAISE NOTICE
                'PASS B02a: Invalid basis rejected';
    END;


    BEGIN
        PERFORM 1
        FROM public.customer_top100_metadata(
            DATE '2026-08-31',
            'invalid_basis'
        );

        RAISE EXCEPTION
            'B02 failed: invalid metadata basis accepted';

    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            RAISE NOTICE
                'PASS B02b: Invalid metadata basis rejected';
    END;


    BEGIN
        PERFORM 1
        FROM public.customer_top100(
            DATE '2026-08-31',
            NULL::text
        );

        RAISE EXCEPTION
            'B02 failed: NULL basis accepted';

    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            RAISE NOTICE
                'PASS B02c: NULL basis rejected';
    END;


    BEGIN
        PERFORM 1
        FROM public.customer_top100_metadata(
            DATE '2026-08-31',
            NULL::text
        );

        RAISE EXCEPTION
            'B02 failed: NULL metadata basis accepted';

    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            RAISE NOTICE
                'PASS B02d: NULL metadata basis rejected';
    END;


    IF EXISTS (
        SELECT 1
        FROM public.customer_spending_totals(NULL::date)
    )
    OR EXISTS (
        SELECT 1
        FROM public.customer_top100(NULL::date)
    )
    OR EXISTS (
        SELECT 1
        FROM public.customer_top100_metadata(NULL::date)
    )
    THEN
        RAISE EXCEPTION
            'B02 failed: NULL date returned records';
    END IF;

    RAISE NOTICE
        'PASS B02e: NULL date behaviour';

END;
$test$;


-- ---------------------------------------------
-- B03: Prepare controlled reporting fixtures
-- ---------------------------------------------

-- Explicit negative order IDs avoid advancing the
-- normal positive order identity sequence.

DO $guard$
BEGIN

    IF EXISTS (
        SELECT 1
        FROM public.orders
        WHERE order_id BETWEEN -910103 AND -910001
    ) THEN
        RAISE EXCEPTION
            'Fixture order ID collision';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.orders
        WHERE order_date < TIMESTAMP '2025-02-01'
    ) THEN
        RAISE EXCEPTION
            'Synthetic reporting period is not empty';
    END IF;

END;
$guard$;


CREATE TEMP TABLE ranking_fixture_customers
ON COMMIT DROP
AS

SELECT
    c.customer_id,

    ROW_NUMBER() OVER (
        ORDER BY c.customer_id
    )::integer AS fixture_position

FROM public.customers c

ORDER BY c.customer_id

LIMIT 103;


INSERT INTO public.orders (
    order_id,
    customer_id,
    order_date,
    status,
    total_amount
)

SELECT
    -910000 - f.fixture_position,

    f.customer_id,

    CASE
        WHEN f.fixture_position <= 2
            THEN TIMESTAMP '2025-01-01 12:00:00'
        ELSE TIMESTAMP '2025-01-02 12:00:00'
    END,

    'completed',

    CASE
        WHEN f.fixture_position <= 99
            THEN 200.00::numeric
        WHEN f.fixture_position <= 102
            THEN 100.00::numeric
        ELSE 99.99::numeric
    END

FROM ranking_fixture_customers f;


DO $test$
BEGIN

    IF (
        SELECT COUNT(*)
        FROM ranking_fixture_customers
    ) <> 103

    OR (
        SELECT COUNT(*)
        FROM public.orders
        WHERE order_id BETWEEN -910103 AND -910001
    ) <> 103

    THEN
        RAISE EXCEPTION
            'B03 failed: incorrect fixture population';
    END IF;

    RAISE NOTICE
        'PASS B03: 103 synthetic orders inserted';

END;
$test$;


-- ---------------------------------------------
-- B04: Fewer than 100 customers
-- ---------------------------------------------

DO $test$
DECLARE
    v_actual record;
    v_basis text;
BEGIN

    FOREACH v_basis IN ARRAY ARRAY[
        'trailing_12_months',
        'recorded_history'
    ]
    LOOP

        SELECT *
        INTO STRICT v_actual

        FROM public.customer_top100_metadata(
            DATE '2025-01-01',
            v_basis
        );

        IF v_actual.qualifying_customer_count <> 2
           OR v_actual.selected_customer_count <> 2
           OR v_actual.cutoff_spending IS NOT NULL
           OR v_actual.customers_at_cutoff <> 0
           OR v_actual.cutoff_customers_selected <> 0
           OR v_actual.cutoff_customers_excluded <> 0
           OR v_actual.has_excluded_cutoff_ties
           OR v_actual.qualifying_spending <> 400.00
           OR v_actual.selected_spending <> 400.00
           OR v_actual.remaining_qualifying_spending <> 0
           OR v_actual.selected_spending_pct <> 100.0000

           OR (
               SELECT COUNT(*)
               FROM public.customer_top100(
                   DATE '2025-01-01',
                   v_basis
               )
           ) <> 2

        THEN
            RAISE EXCEPTION
                'B04 failed for %', v_basis;
        END IF;

        RAISE NOTICE
            'PASS B04: Small population without padding (%)',
            v_basis;

    END LOOP;

END;
$test$;


-- ---------------------------------------------
-- B05-B08: Real deployed-function cutoff ties
-- ---------------------------------------------

DO $test$
DECLARE
    v_basis text;
    v_actual record;
    v_expected_customer integer;
    v_selected_customer integer;
BEGIN

    SELECT f.customer_id
    INTO STRICT v_expected_customer

    FROM ranking_fixture_customers f

    WHERE f.fixture_position = 100;


    FOREACH v_basis IN ARRAY ARRAY[
        'trailing_12_months',
        'recorded_history'
    ]
    LOOP

        -- B05: Compare all 103 ranked records.

        IF EXISTS (

            WITH expected AS (
                SELECT
                    f.customer_id,

                    f.fixture_position::bigint
                        AS ranking_position,

                    CASE
                        WHEN f.fixture_position <= 99
                            THEN 1::bigint
                        WHEN f.fixture_position <= 102
                            THEN 100::bigint
                        ELSE 103::bigint
                    END AS spending_rank,

                    CASE
                        WHEN f.fixture_position <= 99
                            THEN 200.00::numeric
                        WHEN f.fixture_position <= 102
                            THEN 100.00::numeric
                        ELSE 99.99::numeric
                    END AS ranking_spending

                FROM ranking_fixture_customers f
            ),

            actual AS MATERIALIZED (
                SELECT
                    r.customer_id,
                    r.ranking_position,
                    r.spending_rank,
                    r.ranking_spending

                FROM public.customer_spending_ranked(
                    DATE '2025-01-02',
                    v_basis
                ) r
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'B05 failed for %', v_basis;
        END IF;

        RAISE NOTICE
            'PASS B05: Full-population rank and exact precision (%)',
            v_basis;


        -- B06: Exact selected customer membership.

        IF EXISTS (

            WITH expected AS (
                SELECT f.customer_id
                FROM ranking_fixture_customers f
                WHERE f.fixture_position <= 100
            ),

            actual AS MATERIALIZED (
                SELECT r.customer_id

                FROM public.customer_top100(
                    DATE '2025-01-02',
                    v_basis
                ) r
            )

            (
                SELECT * FROM expected
                EXCEPT ALL
                SELECT * FROM actual
            )

            UNION ALL

            (
                SELECT * FROM actual
                EXCEPT ALL
                SELECT * FROM expected
            )

        ) THEN
            RAISE EXCEPTION
                'B06 failed for %', v_basis;
        END IF;


        SELECT r.customer_id
        INTO STRICT v_selected_customer

        FROM public.customer_top100(
            DATE '2025-01-02',
            v_basis
        ) r

        WHERE r.ranking_position = 100
          AND r.spending_rank = 100
          AND r.ranking_spending = 100.00;

        IF v_selected_customer
            IS DISTINCT FROM v_expected_customer
        THEN
            RAISE EXCEPTION
                'B06 failed: incorrect tie-breaker';
        END IF;

        RAISE NOTICE
            'PASS B06: Deterministic cutoff selection (%)',
            v_basis;


        -- B07: Metadata discloses excluded ties.

        SELECT *
        INTO STRICT v_actual

        FROM public.customer_top100_metadata(
            DATE '2025-01-02',
            v_basis
        );

        IF v_actual.qualifying_customer_count <> 103
           OR v_actual.selected_customer_count <> 100
           OR v_actual.cutoff_spending <> 100.00
           OR v_actual.customers_at_cutoff <> 3
           OR v_actual.cutoff_customers_selected <> 1
           OR v_actual.cutoff_customers_excluded <> 2
           OR NOT v_actual.has_excluded_cutoff_ties
        THEN
            RAISE EXCEPTION
                'B07 failed for %', v_basis;
        END IF;

        RAISE NOTICE
            'PASS B07: Three cutoff ties, one selected, two excluded (%)',
            v_basis;


        -- B08: Synthetic financial reconciliation.

        IF v_actual.qualifying_spending <> 20199.99
           OR v_actual.selected_spending <> 19900.00
           OR v_actual.remaining_qualifying_spending <> 299.99
           OR v_actual.selected_spending_pct
                IS DISTINCT FROM
                ROUND(100.0 * 19900.00 / 20199.99, 4)
        THEN
            RAISE EXCEPTION
                'B08 failed for %', v_basis;
        END IF;

        RAISE NOTICE
            'PASS B08: Synthetic financial reconciliation (%)',
            v_basis;

    END LOOP;

END;
$test$;


\echo === Synthetic cutoff metadata before rollback ===

SELECT
    ranking_basis,
    qualifying_customer_count,
    selected_customer_count,
    cutoff_spending,
    customers_at_cutoff,
    cutoff_customers_selected,
    cutoff_customers_excluded,
    has_excluded_cutoff_ties,
    qualifying_spending,
    selected_spending,
    remaining_qualifying_spending

FROM public.customer_top100_metadata(
    DATE '2025-01-02'
);


ROLLBACK;


-- =====================================================
-- PART C: Verify rollback and baseline preservation
-- =====================================================

BEGIN TRANSACTION
ISOLATION LEVEL REPEATABLE READ
READ ONLY;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';

DO $test$
BEGIN

    IF EXISTS (
        SELECT 1
        FROM public.orders
        WHERE order_id BETWEEN -910103 AND -910001
    ) THEN
        RAISE EXCEPTION
            'C01 failed: synthetic orders remain';
    END IF;

    IF TO_REGCLASS(
        'pg_temp.ranking_fixture_customers'
    ) IS NOT NULL
    THEN
        RAISE EXCEPTION
            'C01 failed: temporary fixture table remains';
    END IF;

    RAISE NOTICE
        'PASS C01: Synthetic fixtures removed by rollback';


    IF (SELECT COUNT(*) FROM public.categories) <> 94

       OR (SELECT COUNT(*) FROM public.products) <> 4023

       OR (SELECT COUNT(*) FROM public.customers) <> 40420

       OR (SELECT COUNT(*) FROM public.orders) <> 159384

       OR (SELECT COUNT(*) FROM public.order_items) <> 336559

       OR (SELECT COUNT(*) FROM public.inventory_log) <> 282352

    THEN
        RAISE EXCEPTION
            'C02 failed: baseline counts changed';
    END IF;

    RAISE NOTICE
        'PASS C02: All six baseline table counts preserved';


    IF EXISTS (
        SELECT 1
        FROM public.customer_top100(DATE '2025-01-31')
    ) THEN
        RAISE EXCEPTION
            'C03 failed: synthetic activity remains visible';
    END IF;

    RAISE NOTICE
        'PASS C03: Empty reporting period restored';

END;
$test$;


ROLLBACK;

\echo === All customer ranking verification tests passed ===
