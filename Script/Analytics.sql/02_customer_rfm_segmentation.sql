-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: High-Level RFM Customer Segmentation
-- ========================================================

WITH CustomerRFM AS (
    SELECT
        customer_unique_id,
        -- Recency: Days between customer's last purchase and the end of the Olist dataset
        DATEDIFF(DAY, MAX(order_purchase_timestamp), '2018-09-03') AS recency_days,
        -- Frequency: Total distinct orders placed by this unique customer
        COUNT(DISTINCT order_id) AS total_orders
    FROM gold.fact_sales
    GROUP BY customer_unique_id
)
SELECT
    customer_unique_id,
    recency_days,
    total_orders,
    -- Strategic Marketing Segmentation Rules (Tightly Closed Gaps)
    CASE
        -- 1. High Frequency + Active = Core VIP
        WHEN total_orders >= 2 AND recency_days <= 90 THEN 'Core VIP Loyalist'
        
        -- 2. Inactive long-term regardless of order count = Churned
        WHEN recency_days > 180 THEN 'One-Time Churned'
        
        -- 3. Inactive medium-term = At Risk / Slipping
        WHEN recency_days > 90 AND recency_days <= 180 THEN 'Sleeper / At-Risk Customer'
        
        -- 4. 1 Order + Very Recent = Fresh Onboard
        WHEN total_orders = 1 AND recency_days <= 45 THEN 'Fresh Onboard (Newbie)'
        
        -- 5. Fallback for consistent recent buyers
        ELSE 'Standard Active Buyer'
    END AS customer_segment
FROM CustomerRFM
ORDER BY total_orders DESC, recency_days ASC;
