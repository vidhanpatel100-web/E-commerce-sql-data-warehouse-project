-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Master E-Commerce Portfolio Denormalized Table
-- Description: Combines transactional grains, logistics deltas,
--              deduplicated reviews, and fixed RFM segmentations.
-- ========================================================

WITH CustomerRFM AS (
    -- Subquery to calculate lifecycle metrics per unique customer
    SELECT
        customer_unique_id,
        SUM(item_price) AS total_spend,
        COUNT(DISTINCT order_id) AS total_orders,
        DATEDIFF(DAY, MAX(order_purchase_timestamp), '2018-09-03') AS recency_days,
        DATEDIFF(MONTH, MIN(order_purchase_timestamp), '2018-09-03') AS account_age_months
    FROM gold.fact_sales
    GROUP BY customer_unique_id
),
CustomerSegments AS (
    -- Subquery to assign tight, hierarchical strategic marketing buckets
    SELECT
        customer_unique_id,
        CASE
            -- 1. High-value historical buyers who dropped off = Churned VIPs (Critical to capture!)
            WHEN recency_days > 180 AND total_spend >= 300 THEN 'One-Time Churned (High-Value)'
            
            -- 2. Basic Churned baseline
            WHEN recency_days > 180 THEN 'One-Time Churned'
            
            -- 3. High Frequency + Active + Spend = Core VIP
            WHEN total_orders >= 3 AND total_spend >= 300 AND recency_days <= 180 THEN 'Core VIP Loyalist'
            
            -- 4. Single major ticket purchase, still active
            WHEN total_orders = 1 AND total_spend >= 400 AND recency_days <= 180 THEN 'High-Value Whale'
            
            -- 5. Very recent onboard with regular baseline spend
            WHEN account_age_months <= 2 AND total_spend < 400 AND recency_days <= 45 THEN 'Newbie (Fresh Onboard)'
            
            -- 6. Catch-all fallback
            ELSE 'Standard Active Buyer'
        END AS customer_segment
    FROM CustomerRFM
)
SELECT DISTINCT
    -- 1. Order Keys & Timestamps
    fs.order_id,
    FORMAT(fs.order_purchase_timestamp, 'yyyy-MM') AS order_month_year,
    fs.order_purchase_timestamp,

    -- 2. Logistics & Delivery Performance 
    fs.order_delivered_customer_date,
    fs.order_estimated_delivery_date,
    DATEDIFF(DAY, fs.order_purchase_timestamp, fs.order_delivered_customer_date) AS actual_delivery_days,
    DATEDIFF(DAY, fs.order_delivered_customer_date, fs.order_estimated_delivery_date) AS days_before_or_after_estimate,

    -- 3. Customer Demographics & Behavioral Segment
    dm.customer_unique_id,
    cs.customer_segment, 
    dm.customer_city,
    dm.customer_state,
    dm.customer_zip_code,

    -- 4. Product Details
    fs.product_id,
    dp.product_category,

    -- 5. Financial Metrics
    fs.item_price,
    fs.freight_value, 
    (fs.item_price + fs.freight_value) AS total_customer_transaction_value,

    -- 6. Clean Review Dimensions
    drc.review_id,
    drc.review_score,
    drc.review_title,
    drc.review_message,

    -- 7. Seller Footprint
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    ds.seller_zip_code
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customer dm
    ON fs.customer_unique_id = dm.customer_unique_id
LEFT JOIN CustomerSegments cs
    ON fs.customer_unique_id = cs.customer_unique_id
LEFT JOIN gold.dim_product dp
    ON fs.product_id = dp.product_id
LEFT JOIN gold.dim_review drc 
    ON fs.order_id = drc.order_id
LEFT JOIN gold.dim_seller ds
    ON fs.seller_id = ds.seller_id
WHERE drc.review_id IS NOT NULL;
