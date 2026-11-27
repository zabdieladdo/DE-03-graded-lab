\set ON_ERROR_STOP on
\pset pager off
\timing on
BEGIN;
SET LOCAL statement_timeout='120s';
SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF current_database()<>'kloudkart_lab' THEN RAISE EXCEPTION 'Wrong database'; END IF; END $$;
INSERT INTO public.products(product_id,product_name,category_id,price,stock_quantity,created_at)
VALUES (-960001,'TEST audit movement',NULL,100,5,CURRENT_TIMESTAMP),(-960002,'TEST audit second product',NULL,100,2,CURRENT_TIMESTAMP);
DO $$
DECLARE r record; v_customer bigint; v_order bigint; v_count bigint;
BEGIN
 SELECT min(customer_id) INTO v_customer FROM public.customers;
 SELECT * INTO r FROM public.adjust_stock(-960001,5,'restock','Delivery TEST');
 IF r.success IS DISTINCT FROM true OR NOT EXISTS(SELECT 1 FROM public.inventory_log WHERE log_id=r.log_id AND product_id=-960001 AND change_qty=5 AND reason='restock' AND note='Delivery TEST' AND stock_before=5 AND stock_after=10 AND changed_by=session_user) THEN RAISE EXCEPTION 'A01 restock'; END IF;
 RAISE NOTICE 'PASS A01: restock and audit context';
 SELECT * INTO r FROM public.adjust_stock(-960001,-2,'correction','Count TEST');
 IF r.success IS DISTINCT FROM true OR NOT EXISTS(SELECT 1 FROM public.inventory_log WHERE log_id=r.log_id AND product_id=-960001 AND change_qty=-2 AND reason='correction' AND note='Count TEST' AND stock_before=10 AND stock_after=8) THEN RAISE EXCEPTION 'A02 correction'; END IF;
 RAISE NOTICE 'PASS A02: negative correction';
 SELECT * INTO r FROM public.place_order(v_customer,-960001,3);
 IF r.success IS DISTINCT FROM true THEN RAISE EXCEPTION 'A03 sale refused'; END IF;
 v_order:=r.order_id;
 IF (SELECT count(*) FROM public.inventory_log WHERE product_id=-960001 AND reason='sale')<>1 OR NOT EXISTS(SELECT 1 FROM public.inventory_log WHERE product_id=-960001 AND reason='sale' AND change_qty=-3 AND stock_before=8 AND stock_after=5 AND note=format('Order ID: %s',v_order)) OR NOT EXISTS(SELECT 1 FROM public.orders WHERE order_id=v_order AND total_amount=300) OR NOT EXISTS(SELECT 1 FROM public.order_items WHERE order_id=v_order AND product_id=-960001 AND quantity=3 AND unit_price=100) THEN RAISE EXCEPTION 'A03 sale audit'; END IF;
 RAISE NOTICE 'PASS A03: sale, order reference and exactly one movement';
 UPDATE public.products SET stock_quantity=stock_quantity+1 WHERE product_id IN (-960001,-960002);
 UPDATE public.products SET stock_quantity=stock_quantity WHERE product_id=-960001;
 IF (SELECT count(*) FROM public.inventory_log WHERE product_id IN (-960001,-960002))<>5 OR NOT EXISTS(SELECT 1 FROM public.inventory_log WHERE product_id=-960001 AND change_qty=1 AND stock_before=5 AND stock_after=6 AND reason='correction') OR NOT EXISTS(SELECT 1 FROM public.inventory_log WHERE product_id=-960002 AND change_qty=1 AND stock_before=2 AND stock_after=3 AND reason='correction') THEN RAISE EXCEPTION 'A04 direct/no-op'; END IF;
 RAISE NOTICE 'PASS A04: multi-row direct update and no-op';
 FOR r IN SELECT * FROM (VALUES (-1,'restock','x'),(0,'correction','x'),(1,'sale','x'),(1,'correction',' '),(-7,'correction','x'),(NULL::integer,'correction','x'),(1,NULL::text,'x'),(1,'correction',NULL::text),(2147483647,'restock','x')) AS x(delta,reason,note) LOOP
  IF (SELECT success FROM public.adjust_stock(-960001,r.delta,r.reason,r.note)) IS DISTINCT FROM false THEN RAISE EXCEPTION 'A05 invalid accepted'; END IF;
 END LOOP;
 IF (SELECT success FROM public.adjust_stock(-960099,1,'restock','x')) IS DISTINCT FROM false OR (SELECT success FROM public.place_order(v_customer,-960001,7)) IS DISTINCT FROM false OR (SELECT stock_quantity FROM public.products WHERE product_id=-960001)<>6 OR (SELECT count(*) FROM public.inventory_log WHERE product_id IN (-960001,-960002))<>5 THEN RAISE EXCEPTION 'A05 refusal changed state'; END IF;
 RAISE NOTICE 'PASS A05: invalid requests and insufficient stock leave no movement';
 BEGIN
  PERFORM * FROM public.adjust_stock(-960001,2,'restock','Rollback TEST');
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='intentional rollback';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'intentional rollback' THEN RAISE; END IF;
 END;
 IF (SELECT stock_quantity FROM public.products WHERE product_id=-960001)<>6 OR (SELECT count(*) FROM public.inventory_log WHERE product_id=-960001)<>4 THEN RAISE EXCEPTION 'A06 rollback'; END IF;
 RAISE NOTICE 'PASS A06: adjustment rollback';
END $$;
-- Inject failure after stock update and order insertion, before order item.
CREATE FUNCTION pg_temp.fail_audit_test_item() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.product_id=-960001 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='intentional item failure'; END IF; RETURN NEW; END $$;
CREATE TRIGGER test_fail_audit_item BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_audit_test_item();
DO $$ DECLARE v_customer bigint; v_orders bigint; v_items bigint; BEGIN
 SELECT min(customer_id) INTO v_customer FROM public.customers;
 SELECT count(*) INTO v_orders FROM public.orders;
 SELECT count(*) INTO v_items FROM public.order_items;
 BEGIN
  PERFORM * FROM public.place_order(v_customer,-960001,1);
  RAISE EXCEPTION 'Expected item failure did not occur';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'intentional item failure' THEN RAISE; END IF;
 END;
 IF (SELECT stock_quantity FROM public.products WHERE product_id=-960001)<>6 OR (SELECT count(*) FROM public.inventory_log WHERE product_id=-960001)<>4 OR (SELECT count(*) FROM public.orders)<>v_orders OR (SELECT count(*) FROM public.order_items)<>v_items THEN RAISE EXCEPTION 'A07 partial sale'; END IF;
 RAISE NOTICE 'PASS A07: failure after deduction rolls back stock, order and audit';
END $$;
SELECT product_id,change_qty,reason,stock_before,stock_after,changed_by,note FROM public.inventory_log WHERE product_id IN (-960001,-960002) ORDER BY log_id;
ROLLBACK;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.products WHERE product_id IN (-960001,-960002)) OR EXISTS(SELECT 1 FROM public.inventory_log WHERE product_id IN (-960001,-960002)) OR EXISTS(SELECT 1 FROM public.order_items WHERE product_id IN (-960001,-960002)) OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='test_fail_audit_item' AND tgrelid='public.order_items'::regclass) THEN RAISE EXCEPTION 'A08 fixtures remain'; END IF;
 RAISE NOTICE 'PASS A08: fixtures and failure trigger absent after rollback';
END $$;
