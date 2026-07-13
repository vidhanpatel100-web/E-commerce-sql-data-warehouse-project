-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Top Cities by Customer Density (Regional Targeting)
-- Description: Groups geographic footprints to isolate top buyer locations
--              and calculates localized market share percentages.
-- ========================================================

WITH CleanCityCounts AS (
    -- Step 1: Standardize city text strings to eliminate duplication from raw entries
    SELECT
        UPPER(TRIM(customer_state)) AS customer_state,
        LOWER(TRIM(customer_city)) AS customer_city, -- Standardized casing
        COUNT(DISTINCT customer_unique_id) AS total_unique_customers
    FROM gold.dim_customer
    GROUP BY UPPER(TRIM(customer_state)), LOWER(TRIM(customer_city))
),
TotalWarehouseCustomers AS (
    -- Step 2: Calculate global baseline volume
    SELECT COUNT(DISTINCT customer_unique_id) AS global_grand_total
    FROM gold.dim_customer
)
-- Step 3: Extract top performing regions with exact decimal truncation
SELECT TOP 100
    cc.customer_state,
    cc.customer_city,
    cc.total_unique_customers,
    CAST((cc.total_unique_customers * 100.0) / t.global_grand_total AS DECIMAL(10, 2)) AS market_share_percentage
FROM CleanCityCounts cc
CROSS JOIN TotalWarehouseCustomers t
ORDER BY cc.total_unique_customers DESC;
