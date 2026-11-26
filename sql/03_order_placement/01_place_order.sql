-- DE-03: Kloud Kart
-- Stage 03: Transaction-safe order placement
--
-- Decision: D024 / ADR-002
-- Concurrency strategy: atomic conditional stock update
-- Intended isolation level: READ COMMITTED
--
-- The caller controls the transaction boundary.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

CREATE OR REPLACE FUNCTION public.place_order(
    p_customer_id bigint,
    p_product_id bigint,
    p_quantity integer
)
RETURNS TABLE (
    success boolean,
    order_id bigint,
    message text
)
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$

DECLARE
    v_order_id integer;
    v_unit_price numeric(12, 2);
    v_total_amount numeric(12, 2);

BEGIN

    -- 1. Validate the requested quantity.

    IF p_quantity IS NULL OR p_quantity <= 0 THEN

        RETURN QUERY
        SELECT
            false,
            NULL::bigint,
            'Quantity must be positive'::text;

        RETURN;

    END IF;


    -- 2. Validate the customer.
    --
    -- KEY SHARE prevents deletion or modification
    -- of the referenced customer key until the
    -- caller's transaction finishes.

    PERFORM c.customer_id
    FROM public.customers AS c
    WHERE c.customer_id = p_customer_id
    FOR KEY SHARE;

    IF NOT FOUND THEN

        RETURN QUERY
        SELECT
            false,
            NULL::bigint,
            'Customer not found'::text;

        RETURN;

    END IF;


    -- 3. Atomically check and deduct stock.
    --
    -- PostgreSQL coordinates concurrent updates
    -- to the same product row.
    --
    -- RETURNING captures the price associated
    -- with the successfully updated row.
    --
    -- The monetary guard prevents a purchase
    -- total exceeding NUMERIC(12,2).

    UPDATE public.products AS p
    SET stock_quantity =
        p.stock_quantity - p_quantity

    WHERE p.product_id = p_product_id
        AND p.stock_quantity >= p_quantity
        AND p.price >= 0
        AND p.price * p_quantity <= 9999999999.99

    RETURNING p.price
    INTO v_unit_price;


    -- 4. Handle unsuccessful stock allocation.
    --
    -- No purchase records have been created.
    -- This diagnostic lookup does not authorize
    -- a purchase or perform another deduction.

    IF NOT FOUND THEN

        IF NOT EXISTS (
            SELECT 1
            FROM public.products AS p
            WHERE p.product_id = p_product_id
        ) THEN

            RETURN QUERY
            SELECT
                false,
                NULL::bigint,
                'Product not found'::text;

        ELSE

            RETURN QUERY
            SELECT
                false,
                NULL::bigint,
                'Out of stock or product unavailable for requested quantity'::text;

        END IF;

        RETURN;

    END IF;


    -- 5. Calculate the recorded purchase total.

    v_total_amount :=
        v_unit_price * p_quantity;


    -- 6. Create the order.
    --
    -- The identity column generates the ID.
    -- The recorded status is a documented
    -- lab assumption, not payment verification.

    INSERT INTO public.orders AS o (
        customer_id,
        order_date,
        status,
        total_amount
    )
    VALUES (
        p_customer_id,
        CURRENT_TIMESTAMP,
        'completed',
        v_total_amount
    )
    RETURNING o.order_id
    INTO v_order_id;


    -- 7. Create the corresponding order item.

    INSERT INTO public.order_items (
        order_id,
        product_id,
        quantity,
        unit_price
    )
    VALUES (
        v_order_id,
        p_product_id,
        p_quantity,
        v_unit_price
    );


    -- 8. Record the inventory movement.
    --
    -- Negative quantity represents stock leaving
    -- the business. The note links the movement
    -- to the order that caused it.

    INSERT INTO public.inventory_log (
        product_id,
        change_qty,
        reason,
        created_at,
        note
    )
    VALUES (
        p_product_id,
        -p_quantity,
        'sale',
        CURRENT_TIMESTAMP,
        format('Order ID: %s', v_order_id)
    );


    -- 9. Return exactly one successful result.

    RETURN QUERY
    SELECT
        true,
        v_order_id::bigint,
        'Order placed successfully'::text;

    RETURN;

END;

$function$;

COMMENT ON FUNCTION public.place_order(
    bigint,
    bigint,
    integer
)
IS
'Atomically deducts stock, creates an order and order item,
and records the corresponding inventory movement.
Designed for Read Committed isolation.
The caller controls commit and rollback.';

COMMIT;