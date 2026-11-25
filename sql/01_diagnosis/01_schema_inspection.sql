-- DE-03: Stage 01.2 — Schema inspection
-- Purpose: Establish the existing database structure and guarantees.
-- This script does not modify data or schema.

\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo '=== 1. Database identity ==='

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    current_setting('transaction_isolation') AS isolation_level;

\echo '=== 2. Tables ==='

SELECT
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;

\echo '=== 3. Columns and nullability ==='

SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY
    table_name,
    ordinal_position;

\echo '=== 4. Existing constraints ==='

SELECT
    cls.relname AS table_name,
    con.conname AS constraint_name,
    CASE con.contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
        WHEN 'n' THEN 'NOT NULL'
        WHEN 'x' THEN 'EXCLUSION'
        ELSE con.contype::text
    END AS constraint_type,
    pg_get_constraintdef(con.oid) AS definition,
    con.convalidated AS validated
FROM pg_constraint AS con
JOIN pg_class AS cls
    ON con.conrelid = cls.oid
JOIN pg_namespace AS ns
    ON cls.relnamespace = ns.oid
WHERE ns.nspname = 'public'
ORDER BY
    cls.relname,
    constraint_type,
    con.conname;

\echo '=== 5. Existing indexes ==='

SELECT
    tablename AS table_name,
    indexname AS index_name,
    indexdef AS index_definition
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY
    tablename,
    indexname;

\echo '=== 6. Existing triggers ==='

SELECT
    event_object_table AS table_name,
    trigger_name,
    event_manipulation AS event,
    action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY
    event_object_table,
    trigger_name,
    event_manipulation;

ROLLBACK;