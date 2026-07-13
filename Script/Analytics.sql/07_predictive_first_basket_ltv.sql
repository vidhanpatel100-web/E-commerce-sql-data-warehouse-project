-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: The "First Basket" Predictor (Predictive Product Strategy)
-- Description: Analyzes which initial entry product categories anchor
--              the highest long-term Customer Lifetime Value (LTV).
-- ========================================================

WITH FirstOrderTimestamp AS (
    -- Step 1: Isolate the absolute historical entry timestamp for each unique user
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_time
    FROM gold.fact_sales
    GROUP BY customer_unique_id
),
EntryCategories AS (
    -- Step 2: Extract all distinct product categories present in that first transaction event
    SELECT DISTINCT
        fs.customer_unique_id,
        dp.product_category AS entry_product_category
    FROM gold.fact_sales fs
    JOIN FirstOrderTimestamp fot 
        ON fs.customer_unique_id = fot.customer_unique_id 
        AND fs.order_purchase_timestamp = fot.first_purchase_time
    JOIN gold.dim_product dp 
        ON fs.product_id = dp.product_id
),
CustomerTotalLTV AS (
    -- Step 3: Calculate total historical value metrics per customer profile
    SELECT
        customer_unique_id,
        SUM(item_price) AS global_ltv,
        COUNT(DISTINCT order_id) AS lifetime_orders
    FROM gold.fact_sales
    GROUP BY customer_unique_id
)
-- Step 4: Aggregate long-term value metrics mapped to their respective entry vectors
SELECT TOP 20
    ec.entry_product_category,
    COUNT(ec.customer_unique_id) AS total_customers_onboarded,
    CAST(AVG(tl.global_ltv) AS DECIMAL(10, 2)) AS average_lifetime_value,
    CAST(AVG(CAST(tl.lifetime_orders AS DECIMAL(10, 2))) AS DECIMAL(10, 2)) AS average_lifetime_orders
FROM EntryCategories ec
JOIN CustomerTotalLTV tl 
    ON ec.customer_unique_id = tl.customer_unique_id
GROUP BY ec.entry_product_category
ORDER BY average_lifetime_value DESC;
