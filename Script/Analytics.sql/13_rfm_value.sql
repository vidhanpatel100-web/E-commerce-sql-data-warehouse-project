-- =================================================================================
-- Description: Customer RFM (Recency, Frequency, Monetary) Segmentation Script
-- Target BI Tool: Power BI (Generates a 3-digit RFM cell token for segmentation mapping)
-- Hierarchy: gold.main_table
-- =================================================================================

WITH Customer_Base_Metrics AS (
    SELECT 
        customer_unique_id,
        -- Recency: Days between the global database maximum date and the customer's latest purchase
        DATEDIFF(
            DAY, 
            MAX(CAST(order_purchase_timestamp AS DATETIME)), 
            (SELECT MAX(CAST(order_purchase_timestamp AS DATETIME)) FROM gold.main_table)
        ) AS recency_days,
        
        -- Frequency: Unique order count per user
        COUNT(DISTINCT order_id) AS total_orders,
        
        -- Monetary: Aggregate transactional values across the user life
        SUM(total_customer_transaction_value) AS total_monetary
    FROM gold.main_table
    GROUP BY customer_unique_id
),

RFM_Calculated_Scores AS (
    SELECT 
        customer_unique_id,
        recency_days,
        total_orders,
        total_monetary,
        
        -- R Score: Smallest recency days get the highest rank (5 = Most Recent)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        
        -- F Score: Highest frequency gets the highest rank (5 = Most Frequent)
        NTILE(5) OVER (ORDER BY total_orders ASC) AS f_score,
        
        -- M Score: Highest customer lifetime spend gets the highest rank (5 = Top Spender)
        NTILE(5) OVER (ORDER BY total_monetary ASC) AS m_score
    FROM Customer_Base_Metrics
)

SELECT 
    rfm.customer_unique_id,
    rfm.recency_days,
    rfm.total_orders,
    rfm.total_monetary,
    rfm.r_score,
    rfm.f_score,
    rfm.m_score,
    -- Concatenates columns into a 3-digit indexing token (e.g., '555', '111', '425')
    CONCAT(rfm.r_score, rfm.f_score, rfm.m_score) AS rfm_cell,
    mt.customer_segment,
    mt.product_category
FROM RFM_Calculated_Scores rfm
JOIN gold.main_table mt 
    ON rfm.customer_unique_id = mt.customer_unique_id;
