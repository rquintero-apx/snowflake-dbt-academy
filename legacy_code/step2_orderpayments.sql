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