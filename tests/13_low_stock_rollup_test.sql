\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
DO $$
DECLARE threshold integer; differences bigint; total_low bigint; rooted_low bigint; exception_low bigint;
BEGIN
    IF current_database() <> 'kloudkart_lab' THEN RAISE EXCEPTION 'Wrong database'; END IF;
    FOREACH threshold IN ARRAY ARRAY[1,10,20] LOOP
        -- Independent reference: walk upwards from every category, stop on repeats.
        WITH RECURSIVE walk AS (
            SELECT c.category_id AS start_id,c.category_id,c.parent_id,ARRAY[c.category_id] AS seen
            FROM public.categories c
            UNION ALL
            SELECT w.start_id,c.category_id,c.parent_id,w.seen||c.category_id
            FROM walk w JOIN public.categories c ON c.category_id=w.parent_id
            WHERE NOT c.category_id=ANY(w.seen)
        ), rooted AS (SELECT start_id FROM walk WHERE parent_id IS NULL),
        expected AS (
            SELECT r.start_id AS category_id,
                COUNT(p.product_id) FILTER (WHERE p.stock_quantity<threshold AND p.category_id=r.start_id) AS direct_low_stock_count,
                COUNT(p.product_id) FILTER (WHERE p.stock_quantity<threshold) AS low_stock_count,
                COUNT(p.product_id) FILTER (WHERE p.stock_quantity<0) AS negative_stock_count,
                COUNT(p.product_id) FILTER (WHERE p.stock_quantity=0) AS zero_stock_count,
                COUNT(p.product_id) FILTER (WHERE p.stock_quantity IS NULL) AS unknown_stock_count
            FROM rooted r LEFT JOIN walk w ON w.category_id=r.start_id
            LEFT JOIN public.products p ON p.category_id=w.start_id
            GROUP BY r.start_id
        ), actual AS (
            SELECT category_id,direct_low_stock_count,low_stock_count,negative_stock_count,zero_stock_count,unknown_stock_count
            FROM public.low_stock_category_rollup(threshold)
        ), diff AS ((SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
            UNION ALL (SELECT * FROM actual EXCEPT ALL SELECT * FROM expected))
        SELECT COUNT(*) INTO differences FROM diff;
        IF differences<>0 THEN RAISE EXCEPTION 'L01 threshold %, differences %',threshold,differences; END IF;
        RAISE NOTICE 'PASS L01: independent ancestor counts, threshold %',threshold;
        SELECT COUNT(*) INTO total_low FROM public.products WHERE stock_quantity<threshold;
        SELECT COALESCE(SUM(low_stock_count),0) INTO rooted_low FROM public.low_stock_category_rollup(threshold) WHERE parent_id IS NULL;
        SELECT COUNT(*) INTO exception_low FROM public.v_inventory_category_exceptions WHERE stock_quantity<threshold;
        IF total_low<>rooted_low+exception_low THEN RAISE EXCEPTION 'L02 reconciliation failed'; END IF;
        RAISE NOTICE 'PASS L02: threshold %, total %, rooted %, exceptions %',threshold,total_low,rooted_low,exception_low;
    END LOOP;
    IF (SELECT COUNT(*) FROM public.categories) <> (SELECT COUNT(*) FROM public.v_rooted_category_paths)+(SELECT COUNT(*) FROM public.v_unrooted_categories) THEN RAISE EXCEPTION 'L03 category coverage'; END IF;
    RAISE NOTICE 'PASS L03: category coverage';
    FOREACH threshold IN ARRAY ARRAY[0,-1,NULL]::integer[] LOOP
        BEGIN
            PERFORM * FROM public.low_stock_category_rollup(threshold);
            RAISE EXCEPTION 'L04 invalid threshold accepted';
        EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
        END;
    END LOOP;
    RAISE NOTICE 'PASS L04: invalid thresholds rejected';
END $$;
\echo '=== Root totals ==='
SELECT * FROM public.low_stock_category_rollup() WHERE parent_id IS NULL ORDER BY low_stock_count DESC,category_id;
\echo '=== Unrooted categories ==='
SELECT * FROM public.v_unrooted_categories ORDER BY category_id;
\echo '=== Product exception totals ==='
SELECT coverage,COUNT(*) AS products,COUNT(*) FILTER (WHERE stock_quantity<10) AS low_stock,COUNT(*) FILTER (WHERE stock_quantity IS NULL) AS unknown_stock FROM public.v_inventory_category_exceptions GROUP BY coverage ORDER BY coverage;
\echo '=== Current stock totals ==='
SELECT COUNT(*) AS products,COUNT(*) FILTER (WHERE stock_quantity<10) AS low_stock,COUNT(*) FILTER (WHERE stock_quantity<0) AS negative_stock,COUNT(*) FILTER (WHERE stock_quantity=0) AS zero_stock,COUNT(*) FILTER (WHERE stock_quantity IS NULL) AS unknown_stock FROM public.products;
\echo '=== Rollup plan ==='
EXPLAIN (ANALYZE,BUFFERS) SELECT * FROM public.low_stock_category_rollup() ORDER BY category_id;
ROLLBACK;

-- Synthetic hierarchy: depth beyond baseline, cycle, threshold boundary and zero.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
INSERT INTO public.categories(category_id,category_name,parent_id) VALUES (-950001,'TEST root',NULL);
INSERT INTO public.categories(category_id,category_name,parent_id)
SELECT -950001-i,'TEST depth '||i,-950001-(i-1) FROM generate_series(1,8) i ORDER BY i;
INSERT INTO public.categories(category_id,category_name,parent_id) VALUES (-950020,'TEST cycle A',NULL),(-950021,'TEST cycle B',-950020);
UPDATE public.categories SET parent_id=-950021 WHERE category_id=-950020;
INSERT INTO public.products(product_id,product_name,category_id,price,stock_quantity,created_at) VALUES
(-950001,'TEST low',-950009,1,9,CURRENT_TIMESTAMP),(-950002,'TEST boundary',-950009,1,10,CURRENT_TIMESTAMP),(-950003,'TEST zero',-950009,1,0,CURRENT_TIMESTAMP),(-950004,'TEST cycle product',-950020,1,1,CURRENT_TIMESTAMP);
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.low_stock_category_rollup() WHERE category_id=-950001 AND low_stock_count=2 AND direct_low_stock_count=0 AND zero_stock_count=1) OR
       NOT EXISTS (SELECT 1 FROM public.low_stock_category_rollup() WHERE category_id=-950009 AND depth=9 AND low_stock_count=2 AND direct_low_stock_count=2) THEN RAISE EXCEPTION 'L05 deep hierarchy failed'; END IF;
    RAISE NOTICE 'PASS L05: depth nine, direct/ancestor counts, zero and boundary';
    IF EXISTS (SELECT 1 FROM public.low_stock_category_rollup() WHERE category_id IN (-950020,-950021)) OR
       (SELECT COUNT(*) FROM public.v_unrooted_categories WHERE category_id IN (-950020,-950021))<>2 OR
       NOT EXISTS (SELECT 1 FROM public.v_inventory_category_exceptions WHERE product_id=-950004 AND coverage='unrooted_category') THEN RAISE EXCEPTION 'L06 cycle coverage failed'; END IF;
    RAISE NOTICE 'PASS L06: cycle excluded and product visible';
END $$;
ROLLBACK;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM public.categories WHERE category_id BETWEEN -950021 AND -950001) OR EXISTS (SELECT 1 FROM public.products WHERE product_id BETWEEN -950004 AND -950001) THEN RAISE EXCEPTION 'L07 fixture remains'; END IF;
    RAISE NOTICE 'PASS L07: fixtures absent after rollback';
END $$;
