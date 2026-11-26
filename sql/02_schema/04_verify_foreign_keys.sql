-- DE-03: Kloud Kart
-- Verify foreign key definitions and validation status.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo === Database verification ===

SELECT current_database() AS database_name;

\echo === Foreign key definitions ===

SELECT
    conrelid::regclass AS child_table,
    conname AS constraint_name,
    confrelid::regclass AS parent_table,
    convalidated AS validated,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'f'
    AND connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text, conname;

\echo === Constraint summary ===

SELECT
    COUNT(*) AS total_foreign_keys,
    COUNT(*) FILTER (
        WHERE convalidated
    ) AS validated_foreign_keys,
    COUNT(*) FILTER (
        WHERE NOT convalidated
    ) AS unvalidated_foreign_keys
FROM pg_constraint
WHERE contype = 'f'
    AND connamespace = 'public'::regnamespace;

ROLLBACK;