/*
===============================================================
DDL Script: Deploy Gold Layer Views (Star Schema)
===============================================================
Script Purpose:
    Defines the analytical layer of the data warehouse: one wide
    customer dimension, a line-item grain sales fact table, a
    review-level dimension, and clean seller/product dimensions.

    Uses CREATE OR ALTER so this script can be re-run safely at
    any time without needing a separate DROP step.
===============================================================
*/

-- =============================================================
-- 1. CUSTOMER DIMENSION (Unique Human-Being Grain)
-- =============================================================

CREATE OR ALTER VIEW gold.dim_customer AS  
SELECT
    cf.customer_unique_id,
    MAX(cf.customer_id) AS latest_session_customer_id, 
    COUNT(DISTINCT oi.order_id) AS total_orders_placed,
    MAX(oi.order_status) AS latest_order_status,
  
    MAX(rv.latest_review_score) AS latest_review_score,
    AVG(CAST(rv.avg_review_score AS FLOAT)) AS lifetime_avg_review_score,
    MIN(oi.order_purchase_timestamp) AS first_purchase_date,
    MAX(oi.order_purchase_timestamp) AS latest_order_date,
    cf.customer_zip_code_prefix AS customer_zip_code,
    COALESCE(MAX(gf.geolocation_state), 'Unknown') AS customer_state,
    COALESCE(MAX(gf.geolocation_city), 'Unknown/Unmapped') AS customer_city,
    MAX(gf.geolocation_lat) AS customer_lat,
    MAX(gf.geolocation_lng) AS customer_lng
FROM silver.arc_cust_info cf
-- 1. Deduplicated Geolocation
LEFT JOIN (
    SELECT 
        geolocation_zip_code_prefix,
        MAX(geolocation_city) AS geolocation_city, 
        MAX(geolocation_state) AS geolocation_state,
        AVG(geolocation_lat) AS geolocation_lat, 
        AVG(geolocation_lng) AS geolocation_lng  
    FROM silver.arc_geoloc_info
    GROUP BY geolocation_zip_code_prefix
) gf ON cf.customer_zip_code_prefix = gf.geolocation_zip_code_prefix
-- 2. FIX: Join to Orders using all historical customer keys belonging to that unique person
LEFT JOIN silver.arc_cust_info cf_all 
    ON cf.customer_unique_id = cf_all.customer_unique_id
LEFT JOIN silver.arc_ord_info oi 
    ON cf_all.customer_id = oi.customer_id
-- 3. Left Join to Reviews (Pre-aggregated by order_id)
LEFT JOIN (
    SELECT 
        order_id, 
        MAX(review_score) AS latest_review_score,
        AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM silver.arc_ord_rvew_info
    GROUP BY order_id
) rv ON oi.order_id = rv.order_id
GROUP BY 
    cf.customer_unique_id,
    cf.customer_zip_code_prefix;
GO

-- =============================================================
-- 2. SALES FACT TABLE (Line-Item Revenue Grain)
-- =============================================================
-- NOTE ON GRAIN: total_order_payment and avg_review_score are
-- ORDER-level values that repeat on every line item of that order.
-- SUM(total_order_payment) across items in a multi-item order will
-- overcount the order's true payment total. To get a correct order
-- total, aggregate with COUNT(DISTINCT order_id)-style logic or an
-- LOD expression in Tableau — never a plain SUM() across item rows.
-- avg_review_score is safe to average (it's a repeated constant per
-- order) but not safe to SUM for the same reason.
-- =============================================================
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT
    oit.order_id,
    oit.product_id,
    oit.seller_id,
    oi.customer_id,
    ci.customer_unique_id,
    oi.order_status,
    oit.price AS item_price,
    oit.freight_value,
    COALESCE(pay.total_order_payment, 0) AS total_order_payment,
    COALESCE(rv.avg_review_score, 0)     AS avg_review_score,
    oi.order_purchase_timestamp,
    oi.order_estimated_delivery_date,
    oi.order_delivered_customer_date
FROM silver.arc_ord_item_info oit
INNER JOIN silver.arc_ord_info oi
    ON oit.order_id = oi.order_id
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS total_order_payment
    FROM silver.arc_payment_info
    GROUP BY order_id
) pay ON oit.order_id = pay.order_id
LEFT JOIN (
    SELECT order_id, AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM silver.arc_ord_rvew_info
    GROUP BY order_id
) rv ON oit.order_id = rv.order_id
LEFT JOIN silver.arc_cust_info ci
    ON oi.customer_id = ci.customer_id;
GO

-- =============================================================
-- 3. REVIEW DIMENSION (Granular Feedback Analytics)
-- =============================================================
-- NOTE ON GRAIN: reviews in the Olist source data are captured at
-- the ORDER level, not the product level. Joining to arc_ord_item_info
-- means a review on a multi-product order appears once per product
-- in that order, not once. This is intentional here (it enables
-- category-level sentiment analysis), but it means review_id is NOT
-- unique in this view. Any true review count must use
-- COUNT(DISTINCT review_id), never COUNT(*).
-- =============================================================
CREATE OR ALTER VIEW gold.dim_review AS
SELECT
    rv.review_id,
    orf.order_id,
    oif.product_id,
    pcn.product_category_name_english,
    rv.review_score,
    COALESCE(rv.review_comment_title, 'No Title Provided') AS review_title,
    COALESCE(rv.review_comment_message, 'No Written Comment') AS review_message,
    rv.review_creation_date,
    rv.review_answer_timestamp
FROM silver.arc_ord_rvew_info rv
        LEFT JOIN silver.arc_ord_info orf ON rv.order_id = orf.order_id
        LEFT JOIN silver.arc_ord_item_info oif ON orf.order_id = oif.order_id
        LEFT JOIN silver.arc_prduct_info pif ON oif.product_id = pif.product_id
        LEFT JOIN silver.arc_prdt_ctr_nme_info pcn ON pif.product_category_name = pcn.product_category_name
GO
-- =============================================================
-- 4. SELLER DIMENSION (Clean Merchant Geographics)
-- =============================================================
CREATE OR ALTER VIEW gold.dim_seller AS
SELECT
    si.seller_id,
    si.seller_zip_code_prefix           AS seller_zip_code,
    MAX(gf.geolocation_city)  AS seller_city,
    MAX(gf.geolocation_state) AS seller_state
FROM silver.arc_seler_info si
LEFT JOIN (
    SELECT
        geolocation_zip_code_prefix,
        MAX(geolocation_city)  AS geolocation_city,
        MAX(geolocation_state) AS geolocation_state
    FROM silver.arc_geoloc_info
    GROUP BY geolocation_zip_code_prefix
) gf ON si.seller_zip_code_prefix = gf.geolocation_zip_code_prefix
GROUP BY
    si.seller_id,
    si.seller_zip_code_prefix;
GO

-- =============================================================
-- 5. PRODUCT DIMENSION (Clean E-Commerce Catalog)
-- =============================================================
CREATE OR ALTER VIEW gold.dim_product AS
SELECT
    pi.product_id,
    COALESCE(pn.product_category_name_english, 'Unknown/Uncategorized') AS product_category,
    pi.product_name_lenght        AS product_name_length,
    pi.product_description_lenght AS product_desc_length,
    pi.product_photos_qty         AS product_photos_count,
    pi.product_weight_g           AS product_weight_grams
FROM silver.arc_prduct_info pi
LEFT JOIN silver.arc_prdt_ctr_nme_info pn
    ON pi.product_category_name = pn.product_category_name;
GO
