-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Product Price Tier & Inventory Assortment Distribution
-- Description: Categorizes the product catalog into distinct strategic
--              pricing brackets and audits inventory density per tier.
-- ========================================================

WITH ProductSegments AS (
    -- Step 1: Isolate products and group pricing structures from the warehouse catalog
    SELECT
        fs.product_id,
        dp.product_category,
        fs.item_price,
        CASE 
            WHEN fs.item_price < 50 THEN 'Below 50'
            WHEN fs.item_price BETWEEN 50 AND 100 THEN '50-100'
            WHEN fs.item_price BETWEEN 100 AND 500 THEN '100-500'
            ELSE 'Above 500'
        END AS cost_range
    FROM 
        gold.fact_sales fs
    LEFT JOIN 
        gold.dim_product dp ON fs.product_id = dp.product_id
)
-- Step 2: Evaluate distinct catalog density across pricing tiers
SELECT
    ps.cost_range,
    COUNT(DISTINCT ps.product_id) AS total_distinct_products,
    COUNT(ps.product_id) AS total_transactional_items_sold
FROM 
    ProductSegments ps
GROUP BY 
    ps.cost_range
ORDER BY 
    total_distinct_products DESC;
