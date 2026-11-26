-- DE-03: Kloud Kart
-- Stage 02.4: Essential value constraints
--
-- Purpose:
-- Protect essential numerical values without
-- changing historical records.
--
-- Decision reference: ADR-001 and D022.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

-- 1. Purchase quantities must be positive.
-- No unsupported maximum quantity is imposed.

ALTER TABLE order_items
    ADD CONSTRAINT chk_order_items_quantity
    CHECK (
        quantity IS NOT NULL
        AND quantity > 0
    );

-- 2. New product stock values must be nonnegative.
-- Preserve the 14 historical negative-stock products.

ALTER TABLE products
    ADD CONSTRAINT chk_products_stock
    CHECK (
        stock_quantity IS NOT NULL
        AND stock_quantity >= 0
    ) NOT VALID;

-- 3. Product prices must be nonnegative.
-- Zero-priced products are permitted.

ALTER TABLE products
    ADD CONSTRAINT chk_products_price
    CHECK (
        price IS NOT NULL
        AND price >= 0
    );

-- 4. New order item prices must be nonnegative.
-- Preserve the 148 historical missing prices.
-- Zero-priced items remain permitted.

ALTER TABLE order_items
    ADD CONSTRAINT chk_order_items_unit_price
    CHECK (
        unit_price IS NOT NULL
        AND unit_price >= 0
    ) NOT VALID;

-- 5. Recorded order totals must be nonnegative.

ALTER TABLE orders
    ADD CONSTRAINT chk_orders_total_amount
    CHECK (
        total_amount IS NOT NULL
        AND total_amount >= 0
    );

COMMIT;