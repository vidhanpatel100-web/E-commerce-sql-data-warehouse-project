-- ========================================================
-- E-Commerce Customer Strategy Matrix
-- Module: Year-over-Year (YoY) Product Performance Audit
-- Description: Compares seasonal category sales revenue against both long-term
--              historical averages and prior-year (PY) benchmarks.
-- ========================================================


WITH yearly_product_sales AS(
    SELECT
    FORMAT(forder_purchase_timestamp, 'yyyy') AS order_year,
    product_category AS product_category,
    SUM(item_price) AS current_sales
    FROM gold.main_table
    GROUP BY FORMAT(fs.order_purchase_timestamp, 'yyyy'),
        dp.product_category
)
SELECT
order_year,
product_category,
current_sales,
AVG(current_sales) OVER(PARTITION BY product_category) As avg_sales,
current_sales - AVG(current_sales) OVER(PARTITION BY product_category) AS diff_avg,
CASE
    WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_category) > 0 THEN 'ABOVE AVG'
    WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_category) < 0 THEN 'BELOW AVG'
    ELSE 'AVG'
    END avg_change,
 COALESCE(LAG(current_sales) OVER(PARTITION BY product_category ORDER BY order_year),0) AS py_sales,
 COALESCE(current_sales - LAG(current_sales) OVER(PARTITION BY product_category ORDER BY order_year),0) AS diff_py,
 -- YOY ANALYSIS
 CASE
    WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_category ORDER BY order_year) > 0 THEN 'INCREASE'
    WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_category ORDER BY order_year) < 0 THEN 'DECREASE'
    ELSE 'NO CHANGE'
    END py_change
FROM yearly_product_sales
ORDER BY product_category,order_year
