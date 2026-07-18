-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Complete Analytical Dataset with RFM Segmentations
-- Description: Integrates deep customer lifecycle segmentation metrics 
--              with granular logistics and review dimensions.
-- ========================================================

CREATE OR ALTER VIEW gold.main_table AS

WITH CustomerRFM AS(
    -- Subquery to calculate lifecycle metrics per unique human
    SELECT
        customer_unique_id,
        SUM(item_price) AS total_spend,
        COUNT(DISTINCT order_id) AS total_orders,
        DATEDIFF(DAY, MAX(order_purchase_timestamp), '2018-09-03') AS recency_days,
        DATEDIFF(MONTH, MIN(order_purchase_timestamp), '2018-09-03') AS account_age_months
    FROM gold.fact_sales
    GROUP BY customer_unique_id
),
CustomerSegments AS(
    -- Subquery to assign the strategic marketing buckets
    SELECT
        customer_unique_id,
        CASE
    -- 1. Core VIP Loyalist: Lowered order frequency threshold to 2+ orders (since 97% only buy once) 
    -- and maintained a premium lifetime spend baseline.
    WHEN total_orders >= 2 AND total_spend >= 250 THEN 'Core VIP Loyalist'
    
    -- 2. High-Value Whale: High spenders who have placed 1 massive order, or 2 orders under the VIP monetary threshold.
    WHEN total_spend >= 300 AND (total_orders = 1 OR total_spend < 250) THEN 'High-Value Whale'
    
    -- 3. One-Time Churned: Customers whose last order was over 6 months ago and who never returned.
    WHEN recency_days > 180 THEN 'One-Time Churned'
    
    -- 4. Newbie (Fresh Onboard): Highly active recent buyers who interacted within the last 60 days 
    -- and haven't churned or scaled to high-value yet.
    WHEN recency_days <= 60 THEN 'Newbie (Fresh Onboard)'
    
    -- 5. Standard Active Buyer: The steady middle group (recency between 60 and 180 days, normal spend).
    ELSE 'Standard Active Buyer'
END AS customer_segment
    FROM CustomerRFM
)
SELECT DISTINCT
    -- 1. Order Keys & Timestamps
    fs.order_id,
    FORMAT(fs.order_purchase_timestamp, 'yyyy-MM') AS order_month_year,
    fs.order_purchase_timestamp,

    -- 2. Logistics & Delivery Performance (New Core Metric)
    fs.order_delivered_customer_date,
    fs.order_estimated_delivery_date,
    DATEDIFF(DAY, fs.order_purchase_timestamp, fs.order_delivered_customer_date) AS actual_delivery_days,
    DATEDIFF(DAY, fs.order_delivered_customer_date, fs.order_estimated_delivery_date) AS days_before_or_after_estimate,

    -- 3. Customer Demographics & Behavioral Segment
    dm.customer_unique_id,
    cs.customer_segment, -- Embedded directly for easy filtering in BI tools
    dm.customer_city,
    dm.customer_state,
    dm.customer_zip_code,

    -- 4. Product Details
    fs.product_id,
    dp.product_category,

    -- 5. Financial Metrics (Expanded)
    fs.item_price,
    fs.freight_value, -- New Column: Shipping Cost
(fs.item_price + fs.freight_value) AS total_customer_transaction_value,

    -- 6. Clean Review Dimensions (From your deduplicated gold table)
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
LEFT JOIN gold.dim_review drc -- Utilizing your deduplicated gold review dim
    ON fs.order_id = drc.order_id
LEFT JOIN gold.dim_seller ds
    ON fs.seller_id = ds.seller_id
WHERE drc.review_id IS NOT NULL AND
fs.order_purchase_timestamp IS NOT NULL;
