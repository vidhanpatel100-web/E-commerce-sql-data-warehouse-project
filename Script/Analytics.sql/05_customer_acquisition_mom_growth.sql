-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Month-over-Month (MoM) Customer Acquisition Growth
-- Description: Tracks true first-time user acquisition volume 
--              and calculates net performance growth metrics MoM.
-- ========================================================

WITH CustomerOnboarding AS (
    -- Step 1: Isolate the absolute first purchase timestamp for every unique customer
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_timestamp
    FROM gold.fact_sales
    GROUP BY customer_unique_id
),
MonthlyNewCustomers AS (
    -- Step 2: Aggregate the true onboarding events into monthly time buckets
    SELECT
        DATETRUNC(MONTH, first_purchase_timestamp) AS onboarding_month,
        COUNT(DISTINCT customer_unique_id) AS new_customers_acquired
    FROM CustomerOnboarding
    GROUP BY DATETRUNC(MONTH, first_purchase_timestamp)
),
GrowthCalculations AS (
    -- Step 3: Pull the prior month's metric forward using window functions
    SELECT
        onboarding_month,
        new_customers_acquired,
        LAG(new_customers_acquired, 1) OVER (ORDER BY onboarding_month ASC) AS previous_month_acquisition
    FROM MonthlyNewCustomers
)
SELECT
    FORMAT(onboarding_month, 'yyyy-MM') AS acquisition_period,
    new_customers_acquired,
    ISNULL(previous_month_acquisition, 0) AS previous_month_acquisition,
    COALESCE(
        CAST(
            (new_customers_acquired - previous_month_acquisition) * 100.0 
            / NULLIF(previous_month_acquisition, 0)
        AS DECIMAL(10, 2)), 
        0.00
    ) AS mom_acquisition_growth_percentage
FROM GrowthCalculations
ORDER BY onboarding_month ASC;
