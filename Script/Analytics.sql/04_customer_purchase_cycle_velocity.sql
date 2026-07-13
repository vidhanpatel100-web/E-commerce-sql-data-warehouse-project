-- Order Inter-Arrival Time (The Purchase Cycle Velocity)
WITH OrderedSales AS(
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC) AS purchase_sequence
    FROM gold.fact_sales
),
TimeGaps AS(
    SELECT
        o1.customer_unique_id,
        o1.order_purchase_timestamp AS first_purchase,
        o2.order_purchase_timestamp AS second_purchase,
        DATEDIFF(day, o1.order_purchase_timestamp, o2.order_purchase_timestamp) AS days_between_purchases
    FROM OrderedSales o1
    JOIN OrderedSales o2
        ON o1.customer_unique_id = o2.customer_unique_id
        AND o1.purchase_sequence = 1
        AND o2.purchase_sequence = 2
)
SELECT
    COUNT(customer_unique_id) AS total_repeat_buyers,
    AVG(days_between_purchases) AS average_days_to_second_purchase,
    MIN(days_between_purchases) AS fastest_conversion_days,
    MAX(days_between_purchases) AS slowest_conversion_days
FROM TimeGaps;
