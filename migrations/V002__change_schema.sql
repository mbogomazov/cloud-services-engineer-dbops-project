-- Add price column to product table (from product_info)
ALTER TABLE product ADD COLUMN price DOUBLE PRECISION;
UPDATE product SET price = pi.price FROM product_info pi WHERE product.id = pi.product_id;

-- Add primary key to product
ALTER TABLE product ADD PRIMARY KEY (id);

-- Add date_created column to orders table (from orders_date)
ALTER TABLE orders ADD COLUMN date_created DATE;
UPDATE orders SET date_created = od.date_created FROM orders_date od WHERE orders.id = od.order_id;

-- Add primary key to orders
ALTER TABLE orders ADD PRIMARY KEY (id);

-- Add foreign key constraints to order_product
ALTER TABLE order_product ADD CONSTRAINT fk_order_product_order FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE order_product ADD CONSTRAINT fk_order_product_product FOREIGN KEY (product_id) REFERENCES product(id);

-- Drop unused tables
DROP TABLE product_info;
DROP TABLE orders_date;
