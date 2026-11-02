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