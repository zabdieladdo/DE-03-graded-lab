-- DE-03: Kloud Kart
-- Stage 02.3: Foreign key protection
--
-- Purpose:
-- Prevent new broken references while preserving
-- existing historical records.
--
-- Decision reference: ADR-001 and D021.

\set ON_ERROR_STOP on
\pset pager off
\timing on

BEGIN;

-- 1. Orders must reference existing customers.
-- Historical exceptions: 210.

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id)
    NOT VALID;

-- 2. Order items must reference existing orders.
-- Historical exceptions: 692.

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id)
    NOT VALID;

-- 3. Inventory movements must reference existing products.
-- Historical exceptions: 120.

ALTER TABLE inventory_log
    ADD CONSTRAINT fk_inventory_log_product
    FOREIGN KEY (product_id)
    REFERENCES products (product_id)
    NOT VALID;

-- 4. Non-null category parents must exist.
-- Historical exceptions: 1.

ALTER TABLE categories
    ADD CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id)
    REFERENCES categories (category_id)
    NOT VALID;

-- 5. Order items must reference existing products.
-- Historical exceptions: 0.

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- 6. Non-null product categories must exist.
-- Historical exceptions: 0.

ALTER TABLE products
    ADD CONSTRAINT fk_products_category
    FOREIGN KEY (category_id)
    REFERENCES categories (category_id);

COMMIT;