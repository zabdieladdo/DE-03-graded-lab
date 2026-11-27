\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
DO $$ BEGIN IF current_database() <> 'kloudkart_lab' THEN RAISE EXCEPTION 'Wrong database'; END IF; END $$;

-- A single-parent hierarchy: only categories reachable from roots are valid.
-- The path guard prevents repeated nodes without a fixed depth limit.
CREATE OR REPLACE VIEW public.v_rooted_category_paths AS
WITH RECURSIVE tree AS (
    SELECT c.category_id, c.category_name, c.parent_id,
           c.category_id AS root_id, 1 AS depth,
           ARRAY[c.category_id] AS ancestor_ids,
           COALESCE(c.category_name, '[unnamed]') AS category_path
    FROM public.categories c WHERE c.parent_id IS NULL
    UNION ALL
    SELECT c.category_id, c.category_name, c.parent_id,
           t.root_id, t.depth + 1, t.ancestor_ids || c.category_id,
           t.category_path || ' > ' || COALESCE(c.category_name, '[unnamed]')
    FROM tree t JOIN public.categories c ON c.parent_id = t.category_id
    WHERE NOT c.category_id = ANY(t.ancestor_ids)
)
SELECT * FROM tree;

CREATE OR REPLACE FUNCTION public.low_stock_category_rollup(p_threshold integer DEFAULT 10)
RETURNS TABLE(category_id integer, category_name text, parent_id integer,
    root_id integer, depth integer, category_path text,
    direct_low_stock_count bigint, low_stock_count bigint,
    negative_stock_count bigint, zero_stock_count bigint, unknown_stock_count bigint)
LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    IF p_threshold IS NULL OR p_threshold <= 0 THEN
        RAISE EXCEPTION 'Stock threshold must be a positive integer' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY
    WITH paths AS MATERIALIZED (SELECT * FROM public.v_rooted_category_paths),
    direct AS (
        SELECT p.category_id,
            COUNT(*) FILTER (WHERE p.stock_quantity < p_threshold) AS low_count,
            COUNT(*) FILTER (WHERE p.stock_quantity < 0) AS negative_count,
            COUNT(*) FILTER (WHERE p.stock_quantity = 0) AS zero_count,
            COUNT(*) FILTER (WHERE p.stock_quantity IS NULL) AS unknown_count
        FROM public.products p GROUP BY p.category_id
    ), rolled AS (
        SELECT a.ancestor_id, SUM(d.low_count)::bigint AS low_count,
            SUM(d.negative_count)::bigint AS negative_count,
            SUM(d.zero_count)::bigint AS zero_count,
            SUM(d.unknown_count)::bigint AS unknown_count
        FROM paths t CROSS JOIN LATERAL unnest(t.ancestor_ids) a(ancestor_id)
        JOIN direct d ON d.category_id = t.category_id
        GROUP BY a.ancestor_id
    )
    SELECT t.category_id, t.category_name, t.parent_id, t.root_id, t.depth,
        t.category_path, COALESCE(d.low_count,0), COALESCE(r.low_count,0),
        COALESCE(r.negative_count,0), COALESCE(r.zero_count,0), COALESCE(r.unknown_count,0)
    FROM paths t LEFT JOIN direct d ON d.category_id=t.category_id
    LEFT JOIN rolled r ON r.ancestor_id=t.category_id;
END $$;

CREATE OR REPLACE VIEW public.v_inventory_category_exceptions AS
SELECT p.product_id, p.product_name, p.category_id, p.stock_quantity,
    CASE WHEN p.category_id IS NULL THEN 'uncategorised'
         WHEN c.category_id IS NULL THEN 'missing_category'
         ELSE 'unrooted_category' END AS coverage
FROM public.products p LEFT JOIN public.categories c ON c.category_id=p.category_id
LEFT JOIN public.v_rooted_category_paths t ON t.category_id=p.category_id
WHERE t.category_id IS NULL;

CREATE OR REPLACE VIEW public.v_unrooted_categories AS
SELECT c.category_id,c.category_name,c.parent_id
FROM public.categories c LEFT JOIN public.v_rooted_category_paths t ON t.category_id=c.category_id
WHERE t.category_id IS NULL;

COMMENT ON FUNCTION public.low_stock_category_rollup(integer) IS
'Counts products (not units) with stock strictly below threshold; negative and zero are included, NULL is separate. Each rooted product counts once per ancestor. Unrooted products are reported separately.';
COMMIT;
