-- ==========================================
-- E-Commerce Customer Strategy Matrix
-- Module: Product Review Sentiment Analysis
-- Description: Analyzes product categories by sales volume, delivery delays, and customer sentiment.
-- ==========================================

SELECT
    dp.product_category,
    CAST(AVG(CAST(dr.review_score AS DECIMAL(10, 2))) AS DECIMAL(10, 2)) AS average_review_score,
    COUNT(fs.order_id) AS total_items_purchased,
    AVG(DATEDIFF(day, fs.order_estimated_delivery_date, fs.order_delivered_customer_date)) AS avg_days_delayed,
    CASE 
        WHEN AVG(CAST(dr.review_score AS DECIMAL(10, 2))) >= 4.50 THEN 'Exceptional'
        WHEN AVG(CAST(dr.review_score AS DECIMAL(10, 2))) >= 4.00 THEN 'Highly Satisfied'
        WHEN AVG(CAST(dr.review_score AS DECIMAL(10, 2))) >= 3.00 THEN 'Neutral/Indifferent'
        WHEN AVG(CAST(dr.review_score AS DECIMAL(10, 2))) >= 2.00 THEN 'Low Satisfaction'
        ELSE 'Severe Dissatisfaction'
    END AS category_sentiment
FROM 
    gold.fact_sales fs
JOIN 
    gold.dim_product dp ON fs.product_id = dp.product_id
JOIN 
    gold.dim_review dr ON fs.order_id = dr.order_id
GROUP BY 
    dp.product_category
ORDER BY 
    total_items_purchased DESC;
