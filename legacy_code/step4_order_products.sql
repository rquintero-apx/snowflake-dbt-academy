-- Step 4: Get product details per order from line items
CREATE OR REPLACE TEMPORARY TABLE tmp_order_products AS
SELECT
    li.order_id,
    li.product_id,
    pr.product_name,
    pr.category AS product_category,
    pr.subcategory AS product_subcategory,
    li.quantity,
    li.unit_price,
    li.quantity * li.unit_price AS line_total,
    li.discount_pct,
    li.quantity * li.unit_price * (1 - COALESCE(li.discount_pct, 0) / 100) AS line_total_after_discount,
    CASE
        WHEN pr.category IN ('Electronics', 'Computers', 'Phones') THEN 'Technology'
        WHEN pr.category IN ('Clothing', 'Shoes', 'Accessories') THEN 'Apparel'
        WHEN pr.category IN ('Food', 'Beverages', 'Grocery') THEN 'Consumables'
        WHEN pr.category IN ('Furniture', 'Home Decor', 'Garden') THEN 'Home & Living'
        ELSE 'Other'
    END AS product_department
FROM raw.public.line_items li
JOIN raw.public.products pr
    ON li.product_id = pr.product_id;