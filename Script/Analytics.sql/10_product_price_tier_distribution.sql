-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Product Price Tier & Inventory Assortment Distribution
-- Description: Categorizes the product catalog into distinct strategic
--              pricing brackets and audits inventory density per tier.
-- ========================================================

WITH ProductSegments AS (
    -- Step 1: Isolate products and group pricing structures from the warehouse catalog
SELECT
product_id,
product_category,
item_price,
CASE WHEN item_price < 50 THEN 'Below 50'
	WHEN item_price  BETWEEN 50 AND 100 THEN '50-100'
	WHEN item_price BETWEEN 100 AND 500 THEN '100-500'
	ELSE 'Above 500'
END cost_range
FROM gold.main_table)
-- Step 2: Evaluate distinct catalog density across pricing tiers
SELECT
cost_range,
COUNT(product_id) as total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC


