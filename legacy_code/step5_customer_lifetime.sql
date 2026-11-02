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