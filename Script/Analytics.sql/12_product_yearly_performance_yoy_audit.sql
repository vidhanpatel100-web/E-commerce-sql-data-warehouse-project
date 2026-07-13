-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Year-over-Year (YoY) Product Performance Audit
-- Description: Compares seasonal category sales revenue against both long-term
--              historical averages and prior-year (PY) benchmarks.
-- ========================================================

WITH YearlyProductSales AS (
    -- Step 1: Aggregate sales volumes grouped strictly by calendar year and category
    SELECT
        YEAR(fs.order_purchase_timestamp) AS order_year, -- Optimized: YEAR() performs faster than FORMAT()
        dp.product_category,
        CAST(SUM(fs.item_price) AS DECIMAL(10, 2)) AS current_sales
    FROM 
        gold.fact_sales fs
    LEFT JOIN 
        gold.dim_product dp ON fs.product_id = dp.product_id
    WHERE 
        fs.order_purchase_timestamp IS NOT NULL
        AND dp.product_category IS NOT NULL
    GROUP BY 
        YEAR(fs.order_purchase_timestamp),
        dp.product_category
),
PerformanceMetrics AS (
    -- Step 2: Compute window analytics for long-term averages and lagging periods
    SELECT
        order_year,
        product_category,
        current_sales,
        CAST(AVG(current_sales) OVER (PARTITION BY product_category) AS DECIMAL(10, 2)) AS avg_historical_sales,
        LAG(current_sales, 1) OVER (PARTITION BY product_category ORDER BY order_year) AS prior_year_sales
    FROM 
        YearlyProductSales
)
-- Step 3: Run final delta evaluations with tight null protection systems
SELECT
    pm.order_year,
    pm.product_category,
    pm.current_sales,
    pm.avg_historical_sales,
    
    -- 1. Performance against historical category norm
    CAST((pm.current_sales - pm.avg_historical_sales) AS DECIMAL(10, 2)) AS diff_from_avg,
    CASE
        WHEN (pm.current_sales - pm.avg_historical_sales) > 0 THEN 'ABOVE AVG'
        WHEN (pm.current_sales - pm.avg_historical_sales) < 0 THEN 'BELOW AVG'
        ELSE 'HISTORICAL NORM'
    END AS historical_performance_tier,
    
    -- 2. Performance against prior year (YoY Tracking)
    ISNULL(pm.prior_year_sales, 0.00) AS prior_year_sales,
    CAST(ISNULL(pm.current_sales - pm.prior_year_sales, pm.current_sales) AS DECIMAL(10, 2)) AS diff_prior_year,
    CASE
        WHEN pm.prior_year_sales IS NULL THEN 'NEW ACQUISITION LAUNCH' -- Fixed: explicitly labels baseline years
        WHEN (pm.current_sales - pm.prior_year_sales) > 0 THEN 'GROWTH INCREASE'
        WHEN (pm.current_sales - pm.prior_year_sales) < 0 THEN 'VOLUME DECREASE'
        ELSE 'STAGNANT STABLE'
    END AS yoy_trend_status
FROM 
    PerformanceMetrics pm
ORDER BY 
    pm.product_category ASC,
    pm.order_year ASC;
