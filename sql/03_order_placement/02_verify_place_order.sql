-- DE-03: Verify deployed purchase function.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo === 1. Database identity ===

SELECT current_database() AS database_name;

\echo === 2. Transaction isolation ===

SHOW transaction_isolation;

\echo === 3. Connection capacity ===

SHOW max_connections;

\echo === 4. Purchase function definition ===

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid)
        AS arguments,
    pg_get_function_result(p.oid)
        AS return_type,
    l.lanname AS language,
    CASE p.provolatile
        WHEN 'v' THEN 'VOLATILE'
        WHEN 's' THEN 'STABLE'
        WHEN 'i' THEN 'IMMUTABLE'
    END AS volatility,
    p.prosecdef AS security_definer

FROM pg_proc AS p

JOIN pg_namespace AS n
    ON n.oid = p.pronamespace

JOIN pg_language AS l
    ON l.oid = p.prolang

WHERE n.nspname = 'public'
    AND p.proname = 'place_order';

\echo === 5. Exact required signature ===

SELECT
    to_regprocedure(
        'public.place_order(bigint,bigint,integer)'
    ) IS NOT NULL AS required_signature_exists;

\echo === 6. Function overload count ===

SELECT COUNT(*) AS function_count
FROM pg_proc AS p
JOIN pg_namespace AS n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
    AND p.proname = 'place_order';

ROLLBACK;