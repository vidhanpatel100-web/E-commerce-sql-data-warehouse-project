-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Executive KPI Summary Card Deck
-- Description: Aggregates global North Star metrics across sales,
--              logistics, and reviews into a unified key-value matrix.
-- ========================================================

SELECT 
    'Total Registered Customers' AS kpi_name, 
    CAST(COUNT(DISTINCT customer_unique_id) AS DECIMAL(10,2)) AS metric_value 
FROM gold.dim_customer

UNION ALL

SELECT 
    'Total Transactional Sales', 
    CAST(SUM(item_price) AS DECIMAL(10,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Average Item Basket Price', 
    CAST(AVG(item_price) AS DECIMAL(10,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Reviews Logged', 
    CAST(COUNT(DISTINCT review_id) AS DECIMAL(10,2)) 
FROM gold.dim_review

UNION ALL

SELECT 
    'Average Customer Rating Score', 
    CAST(AVG(CAST(review_score AS DECIMAL(10,2))) AS DECIMAL(10,2)) 
FROM gold.dim_review

UNION ALL

SELECT 
    'Total Gross Orders Placed', 
    CAST(COUNT(DISTINCT order_id) AS DECIMAL(10,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Unique Products in Catalog', 
    CAST(COUNT(product_id) AS DECIMAL(10,2)) 
FROM gold.dim_product

UNION ALL

SELECT 
    'Total Unique Buying Hubs (Cities)', 
    CAST(COUNT(DISTINCT customer
