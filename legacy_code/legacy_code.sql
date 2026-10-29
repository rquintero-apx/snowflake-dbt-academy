-- ============================================================
-- LEGACY CODE: Monthly Business Performance Report
-- Purpose: Generates a monthly summary of orders, revenue,
--          customer segments, and product performance.
-- Owner: unknown (inherited)
-- Last modified: 2021-03-14
-- WARNING: Do not modify without approval from the data team.
-- ============================================================

-- Step 1: Clean up raw customers (some have duplicate emails, nulls, bad dates)
CREATE OR REPLACE TEMPORARY TABLE tmp_cleaned_customers AS
SELECT
    c.customer_id,
    UPPER(TRIM(c.first_name)) AS first_name,
    UPPER(TRIM(c.last_name)) AS last_name,
    LOWER(TRIM(c.email)) AS email,
    COALESCE(c.phone, 'N/A') AS phone,
    c.created_at,
    CASE
        WHEN c.country IS NULL OR c.country = '' THEN 'UNKNOWN'
        WHEN c.country IN ('US', 'USA', 'United States', 'united states') THEN 'US'
        WHEN c.country IN ('UK', 'GB', 'United Kingdom', 'united kingdom', 'Great Britain') THEN 'UK'
        WHEN c.country IN ('CA', 'Canada', 'canada') THEN 'CA'
        WHEN c.country IN ('DE', 'Germany', 'germany') THEN 'DE'
        WHEN c.country IN ('FR', 'France', 'france') THEN 'FR'
        ELSE UPPER(c.country)
    END AS country_standardized,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(c.email)) ORDER BY c.created_at DESC) AS rn
FROM raw.public.customers c
WHERE c.created_at IS NOT NULL
  AND c.email IS NOT NULL
  AND c.email LIKE '%@%';

DELETE FROM tmp_cleaned_customers WHERE rn > 1;

-- Step 2: Clean up raw orders and join with payments
CREATE OR REPLACE TEMPORARY TABLE tmp_order_payments AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status AS order_status,
    o.shipping_method,
    CASE
        WHEN o.status = 'completed' THEN 'completed'
        WHEN o.status = 'shipped' THEN 'in_transit'
        WHEN o.status IN ('pending', 'processing') THEN 'open'
        WHEN o.status IN ('cancelled', 'canceled', 'refunded') THEN 'cancelled'
        ELSE 'other'
    END AS order_status_clean,
    p.payment_id,
    p.payment_method,
    COALESCE(p.amount, 0) AS payment_amount,
    CASE
        WHEN p.payment_method IN ('credit_card', 'cc', 'visa', 'mastercard', 'amex') THEN 'credit_card'
        WHEN p.payment_method IN ('bank_transfer', 'wire', 'ach') THEN 'bank_transfer'
        WHEN p.payment_method IN ('paypal', 'venmo') THEN 'digital_wallet'
        WHEN p.payment_method = 'gift_card' THEN 'gift_card'
        ELSE 'other'
    END AS payment_method_clean,
    p.status AS payment_status
FROM raw.public.orders o
LEFT JOIN raw.public.payments p
    ON o.order_id = p.order_id
WHERE o.order_date >= '2020-01-01'
  AND o.order_date < DATEADD('month', 1, DATE_TRUNC('month', CURRENT_DATE()));

-- Step 3: Build order-level revenue (an order can have multiple payments)
CREATE OR REPLACE TEMPORARY TABLE tmp_order_revenue AS
SELECT
    op.order_id,
    op.customer_id,
    op.order_date,
    op.order_status_clean AS order_status,
    op.shipping_method,
    SUM(CASE WHEN op.payment_status = 'success' THEN op.payment_amount ELSE 0 END) AS gross_revenue,
    SUM(CASE WHEN op.payment_status = 'refund' THEN op.payment_amount ELSE 0 END) AS refund_amount,
    SUM(CASE WHEN op.payment_status = 'success' THEN op.payment_amount ELSE 0 END)
        - SUM(CASE WHEN op.payment_status = 'refund' THEN op.payment_amount ELSE 0 END) AS net_revenue,
    COUNT(DISTINCT op.payment_id) AS payment_count,
    LISTAGG(DISTINCT op.payment_method_clean, ', ') WITHIN GROUP (ORDER BY op.payment_method_clean) AS payment_methods_used
FROM tmp_order_payments op
GROUP BY 1, 2, 3, 4, 5;

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

-- Step 5: Customer lifetime metrics (expensive - scans entire history every run)
CREATE OR REPLACE TEMPORARY TABLE tmp_customer_lifetime AS
SELECT
    customer_id,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS most_recent_order_date,
    COUNT(DISTINCT order_id) AS lifetime_order_count,
    SUM(net_revenue) AS lifetime_revenue,
    AVG(net_revenue) AS avg_order_value,
    DATEDIFF('day', MIN(order_date), MAX(order_date)) AS customer_tenure_days,
    DATEDIFF('day', MAX(order_date), CURRENT_DATE()) AS days_since_last_order,
    CASE
        WHEN COUNT(DISTINCT order_id) = 1 THEN 'One-time'
        WHEN COUNT(DISTINCT order_id) BETWEEN 2 AND 4 THEN 'Occasional'
        WHEN COUNT(DISTINCT order_id) BETWEEN 5 AND 10 THEN 'Regular'
        WHEN COUNT(DISTINCT order_id) > 10 THEN 'VIP'
    END AS customer_segment,
    CASE
        WHEN DATEDIFF('day', MAX(order_date), CURRENT_DATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF('day', MAX(order_date), CURRENT_DATE()) <= 90 THEN 'At Risk'
        WHEN DATEDIFF('day', MAX(order_date), CURRENT_DATE()) <= 180 THEN 'Lapsing'
        ELSE 'Churned'
    END AS activity_status
FROM tmp_order_revenue
GROUP BY customer_id;

-- Step 6: Monthly aggregation with customer and product dimensions
CREATE OR REPLACE TEMPORARY TABLE tmp_monthly_summary AS
SELECT
    DATE_TRUNC('month', orv.order_date) AS report_month,
    cc.country_standardized AS customer_country,
    cl.customer_segment,
    cl.activity_status,
    op.product_department,
    op.product_category,

    -- Order metrics
    COUNT(DISTINCT orv.order_id) AS total_orders,
    COUNT(DISTINCT orv.customer_id) AS unique_customers,
    COUNT(DISTINCT CASE WHEN cl.lifetime_order_count = 1 THEN orv.customer_id END) AS new_customers,
    COUNT(DISTINCT CASE WHEN cl.lifetime_order_count > 1 THEN orv.customer_id END) AS returning_customers,

    -- Revenue metrics
    SUM(orv.gross_revenue) AS total_gross_revenue,
    SUM(orv.refund_amount) AS total_refunds,
    SUM(orv.net_revenue) AS total_net_revenue,
    AVG(orv.net_revenue) AS avg_order_value,

    -- Product metrics
    SUM(op.quantity) AS total_units_sold,
    SUM(op.line_total) AS total_product_revenue_before_discount,
    SUM(op.line_total_after_discount) AS total_product_revenue_after_discount,
    SUM(op.line_total) - SUM(op.line_total_after_discount) AS total_discount_given,
    CASE
        WHEN SUM(op.line_total) > 0
        THEN ROUND((SUM(op.line_total) - SUM(op.line_total_after_discount)) / SUM(op.line_total) * 100, 2)
        ELSE 0
    END AS discount_rate_pct,

    -- Shipping breakdown (hardcoded, brittle)
    COUNT(DISTINCT CASE WHEN orv.shipping_method = 'standard' THEN orv.order_id END) AS standard_shipping_orders,
    COUNT(DISTINCT CASE WHEN orv.shipping_method = 'express' THEN orv.order_id END) AS express_shipping_orders,
    COUNT(DISTINCT CASE WHEN orv.shipping_method = 'overnight' THEN orv.order_id END) AS overnight_shipping_orders

FROM tmp_order_revenue orv
INNER JOIN tmp_cleaned_customers cc
    ON orv.customer_id = cc.customer_id
INNER JOIN tmp_customer_lifetime cl
    ON orv.customer_id = cl.customer_id
INNER JOIN tmp_order_products op
    ON orv.order_id = op.order_id
GROUP BY 1, 2, 3, 4, 5, 6;

-- Step 7: Final output with ranking and formatting
SELECT
    TO_CHAR(ms.report_month, 'YYYY-MM') AS report_month,
    ms.customer_country,
    ms.customer_segment,
    ms.activity_status,
    ms.product_department,
    ms.product_category,
    ms.total_orders,
    ms.unique_customers,
    ms.new_customers,
    ms.returning_customers,
    ROUND(ms.new_customers / NULLIF(ms.unique_customers, 0) * 100, 1) AS new_customer_pct,
    '$' || TO_CHAR(ms.total_gross_revenue, '999,999,999.99') AS total_gross_revenue,
    '$' || TO_CHAR(ms.total_refunds, '999,999,999.99') AS total_refunds,
    '$' || TO_CHAR(ms.total_net_revenue, '999,999,999.99') AS total_net_revenue,
    '$' || TO_CHAR(ms.avg_order_value, '999,999.99') AS avg_order_value,
    ms.total_units_sold,
    ms.discount_rate_pct || '%' AS discount_rate,
    ms.standard_shipping_orders,
    ms.express_shipping_orders,
    ms.overnight_shipping_orders,

    -- Rank categories by revenue within each month
    RANK() OVER (
        PARTITION BY ms.report_month, ms.customer_country
        ORDER BY ms.total_net_revenue DESC
    ) AS revenue_rank_in_country,

    -- Month-over-month growth (self-join on previous month)
    ROUND(
        (ms.total_net_revenue - prev.total_net_revenue)
        / NULLIF(prev.total_net_revenue, 0) * 100, 1
    ) AS mom_revenue_growth_pct,

    CURRENT_TIMESTAMP() AS report_generated_at

FROM tmp_monthly_summary ms
LEFT JOIN tmp_monthly_summary prev
    ON ms.customer_country = prev.customer_country
    AND ms.customer_segment = prev.customer_segment
    AND ms.product_department = prev.product_department
    AND ms.product_category = prev.product_category
    AND ms.activity_status = prev.activity_status
    AND prev.report_month = DATEADD('month', -1, ms.report_month)
WHERE ms.total_orders > 0
ORDER BY
    ms.report_month DESC,
    ms.customer_country,
    ms.total_net_revenue DESC;

-- Cleanup
DROP TABLE IF EXISTS tmp_cleaned_customers;
DROP TABLE IF EXISTS tmp_order_payments;
DROP TABLE IF EXISTS tmp_order_revenue;
DROP TABLE IF EXISTS tmp_order_products;
DROP TABLE IF EXISTS tmp_customer_lifetime;
DROP TABLE IF EXISTS tmp_monthly_summary;
