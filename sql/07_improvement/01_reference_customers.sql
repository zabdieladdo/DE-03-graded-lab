-- E060a: independent reference, not a deployed routine.
-- Execute through psycopg2 with as_of_date bound as a date.
-- Deliberately does not call reporting functions or views.
WITH params AS (
    SELECT %(as_of_date)s::date AS cutoff,
           (date_trunc('month', %(as_of_date)s::date) - interval '11 months')::date AS window_start
), eligible AS MATERIALIZED (
    SELECT o.customer_id, o.order_date, o.total_amount
    FROM public.orders o CROSS JOIN params p
    WHERE lower(btrim(o.status)) IN ('complete', 'completed')
      AND o.order_date < p.cutoff + interval '1 day'
), history AS (
    SELECT e.customer_id, count(*) AS history_count, sum(e.total_amount) AS history_amount,
           min(e.order_date) AS first_order_date, max(e.order_date) AS last_order_date,
           coalesce(sum(e.total_amount) FILTER (WHERE e.order_date < p.window_start), 0) AS opening_amount,
           count(*) FILTER (WHERE e.order_date < p.window_start) AS opening_count
    FROM eligible e CROSS JOIN params p
    GROUP BY e.customer_id
), monthly AS (
    SELECT e.customer_id, date_trunc('month', e.order_date)::date AS month,
           sum(e.total_amount) AS amount, count(*) AS n
    FROM eligible e CROSS JOIN params p
    WHERE e.order_date >= p.window_start
    GROUP BY e.customer_id, date_trunc('month', e.order_date)::date
), months AS (
    SELECT g.month::date AS month
    FROM params p CROSS JOIN LATERAL generate_series(
        p.window_start::timestamp, p.window_start::timestamp + interval '11 months', interval '1 month'
    ) AS g(month)
), dense AS (
    SELECT c.customer_id,
           array_agg(m.month ORDER BY m.month) AS months,
           array_agg(coalesce(a.amount, 0) ORDER BY m.month) AS monthly_amounts,
           array_agg(coalesce(a.n, 0) ORDER BY m.month) AS monthly_counts
    FROM public.customers c CROSS JOIN months m
    LEFT JOIN monthly a ON a.customer_id = c.customer_id AND a.month = m.month
    GROUP BY c.customer_id
)
SELECT c.customer_id, c.full_name,
       coalesce(h.history_count, 0) AS history_count,
       coalesce(h.history_amount, 0) AS history_amount,
       h.first_order_date, h.last_order_date,
       coalesce(h.opening_amount, 0) AS opening_amount,
       coalesce(h.opening_count, 0) AS opening_count,
       d.months, d.monthly_amounts, d.monthly_counts
FROM public.customers c JOIN dense d USING (customer_id)
LEFT JOIN history h USING (customer_id)
ORDER BY c.customer_id;
