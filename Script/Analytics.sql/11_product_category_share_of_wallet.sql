-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Product Category Revenue Contribution (Share of Wallet)
-- Description: Measures the gross financial contribution of individual product verticals
--              against the global dataset baseline via analytic window functions.
-- ========================================================

WITH CategorySales AS (
    -- Step 1: Aggregate absolute transaction values per individual category vertical
    SELECT
        dp.product_category,
        SUM(fs.item_price) AS total_sales_revenue
    FROM 
        gold.fact_sales fs
    LEFT JOIN 
        gold.dim_product dp ON fs.product_id = dp.product_id
    GROUP BY 
        dp.product_category
)
-- Step 2: Compute relative market share distributions using window aggregates
SELECT
    cs.product_category,
    CAST(cs.total_sales_revenue AS DECIMAL(10, 2)) AS total_sales_revenue,
    CAST(SUM(cs.total_sales_revenue) OVER () AS DECIMAL(10, 2)) AS global_grand_total_revenue,
    
    -- Returns a clean numeric ratio, perfect for immediate visualization sorting
    CAST(
        (cs.total_sales_revenue * 100.0) / SUM(cs.total_sales_revenue) OVER () 
    AS DECIMAL(10, 2)) AS revenue_contribution_percentage
FROM 
    CategorySales cs
ORDER BY 
    cs.total_sales_revenue DESC;
