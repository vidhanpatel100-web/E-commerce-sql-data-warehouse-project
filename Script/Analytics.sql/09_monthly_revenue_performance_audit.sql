-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Month-over-Month Revenue & Volume Performance Audit
-- Description: Tracks continuous chronological growth trends by auditing
--              sales revenue alongside internal user metrics.
-- ========================================================

SELECT
    YEAR(fs.order_purchase_timestamp) AS order_year,
    MONTH(fs.order_purchase_timestamp) AS order_month,
    -- Formats timestamps into a clean, standardized chronological string for easy BI charting
    FORMAT(fs.order_purchase_timestamp, 'yyyy-MM') AS performance_period,
    
    CAST(SUM(fs.item_price) AS DECIMAL(10, 2)) AS total_sales_revenue,
    
    -- Differentiating transaction entries from absolute unique buyers
    COUNT(DISTINCT fs.customer_id) AS total_order_transactions,
    COUNT(DISTINCT fs.customer_unique_id) AS total_unique_customers_active
FROM 
    gold.fact_sales fs
WHERE 
    fs.order_purchase_timestamp IS NOT NULL
GROUP BY 
    YEAR(fs.order_purchase_timestamp),
    MONTH(fs.order_purchase_timestamp),
    FORMAT(fs.order_purchase_timestamp, 'yyyy-MM')
ORDER BY 
    order_year ASC, 
    order_month ASC;
