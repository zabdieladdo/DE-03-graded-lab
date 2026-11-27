-- E060a: independent history reconciliation and exception measures.
-- Affected recorded order value is not verified loss or missing item value.
WITH params AS (SELECT %(as_of_date)s::date AS cutoff),
eligible AS MATERIALIZED (
    SELECT o.order_id, o.customer_id, o.total_amount
    FROM public.orders o CROSS JOIN params p
    WHERE lower(btrim(o.status)) IN ('complete', 'completed')
      AND o.order_date < p.cutoff + interval '1 day'
), valuations AS (
    SELECT e.order_id, e.total_amount,
           c.customer_id IS NOT NULL AS attributed,
           count(i.order_item_id) AS line_count,
           count(*) FILTER (WHERE i.order_item_id IS NOT NULL AND
               (i.quantity IS NULL OR i.unit_price IS NULL)) AS incomplete_lines,
           sum(i.quantity * i.unit_price) AS item_amount
    FROM eligible e LEFT JOIN public.customers c ON c.customer_id = e.customer_id
    LEFT JOIN public.order_items i ON i.order_id = e.order_id
    GROUP BY e.order_id, e.total_amount, c.customer_id
), classified AS (
    SELECT *, line_count = 0 OR incomplete_lines > 0 AS incomplete,
           line_count > 0 AND incomplete_lines = 0 AND total_amount <> item_amount AS mismatch
    FROM valuations
), dates AS (
    SELECT count(*) FILTER (WHERE o.order_date IS NULL) AS missing_date_count,
           count(*) FILTER (WHERE o.order_date >= p.cutoff + interval '1 day') AS after_cutoff_count,
           coalesce(sum(o.total_amount) FILTER (WHERE o.order_date IS NULL), 0) AS missing_date_value,
           coalesce(sum(o.total_amount) FILTER (WHERE o.order_date >= p.cutoff + interval '1 day'), 0) AS after_cutoff_value
    FROM public.orders o CROSS JOIN params p
    WHERE lower(btrim(o.status)) IN ('complete', 'completed')
), email_groups AS (
    SELECT lower(btrim(email)) AS email_key, count(*) AS n
    FROM public.customers WHERE email IS NOT NULL AND btrim(email) <> ''
    GROUP BY lower(btrim(email)) HAVING count(*) > 1
), totals AS (
    SELECT count(*) AS eligible_orders, coalesce(sum(total_amount), 0) AS eligible_value,
           count(*) FILTER (WHERE attributed) AS attributed_orders,
           coalesce(sum(total_amount) FILTER (WHERE attributed), 0) AS attributed_value,
           count(*) FILTER (WHERE NOT attributed) AS unattributed_orders,
           coalesce(sum(total_amount) FILTER (WHERE NOT attributed), 0) AS unattributed_value,
           count(*) FILTER (WHERE mismatch) AS mismatch_orders,
           coalesce(sum(abs(total_amount - item_amount)) FILTER (WHERE mismatch), 0) AS mismatch_absolute_gap,
           coalesce(sum(total_amount) FILTER (WHERE mismatch), 0) AS mismatch_recorded_value,
           count(*) FILTER (WHERE incomplete) AS incomplete_orders,
           coalesce(sum(total_amount) FILTER (WHERE incomplete), 0) AS incomplete_recorded_value,
           count(*) FILTER (WHERE line_count = 0) AS no_item_orders,
           count(*) FILTER (WHERE total_amount IS NULL) AS null_header_amount_orders
    FROM classified
)
SELECT totals.*, dates.*,
       (SELECT count(*) FROM email_groups) AS shared_email_groups,
       (SELECT coalesce(sum(n), 0) FROM email_groups) AS shared_email_accounts
FROM totals CROSS JOIN dates;
