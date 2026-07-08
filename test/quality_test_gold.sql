/*
===============================================================================
GOLD LAYER — MASTER QUALITY ASSURANCE SUITE
E-Commerce Data Warehouse | SQL Server
===============================================================================
Consolidated diagnostic suite: relational integrity, grain/duplicate checks,
chronological sanity, metric boundaries, null audits, and source data gap
tracing across the Gold layer (Star Schema).

Run sequentially after deploying/redeploying the Gold views.
===============================================================================
*/

-- ============================================================================
-- SECTION 1: ROW COUNT OVERVIEW
-- ============================================================================

SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM gold.dim_customer
UNION ALL
SELECT 'fact_sales',    COUNT(*) FROM gold.fact_sales
UNION ALL
SELECT 'dim_review',    COUNT(*) FROM gold.dim_review
UNION ALL
SELECT 'dim_seller',    COUNT(*) FROM gold.dim_seller
UNION ALL
SELECT 'dim_product',   COUNT(*) FROM gold.dim_product;
GO


-- ============================================================================
-- SECTION 2: GRAIN & DUPLICATE INTEGRITY CHECKS
-- ============================================================================

PRINT 'Check: dim_customer grain — exactly one row per person...';
-- Expectation: 0 rows returned
SELECT customer_unique_id, COUNT(*) AS row_count
FROM gold.dim_customer
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;


PRINT 'Check: LTV granularity — dim_customer order counts match fact_sales...';
-- Verifies the customer dimension's total_orders_placed agrees with a live
-- distinct count of orders in the fact table for that same person.
-- Expectation: 0 rows returned
SELECT TOP 10
    c.customer_unique_id,
    c.total_orders_placed AS dim_order_count,
    COUNT(DISTINCT f.order_id) AS fact_order_count
FROM gold.dim_customer c
INNER JOIN gold.fact_sales f
    ON c.customer_unique_id = f.customer_unique_id
GROUP BY c.customer_unique_id, c.total_orders_placed
HAVING c.total_orders_placed <> COUNT(DISTINCT f.order_id);


PRINT 'Check: dim_review order/product grain — how much fan-out exists...';
-- Reviews are captured per order, not per product, so a review on a
-- multi-product order legitimately appears more than once here.
-- Expectation: informational — matches (row_count_of_review_id, > 1) pattern
-- for orders with more than one product; review_id itself stays traceable.
SELECT order_id, product_id, COUNT(*) AS row_count
FROM gold.dim_review
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;
GO


-- ============================================================================
-- SECTION 3: NULL AUDITS — ALL 5 GOLD OBJECTS
-- ============================================================================

PRINT 'Check: dim_customer null audit...';
SELECT
    SUM(CASE WHEN customer_unique_id         IS NULL THEN 1 ELSE 0 END) AS customer_unique_id_nulls,
    SUM(CASE WHEN latest_session_customer_id IS NULL THEN 1 ELSE 0 END) AS latest_customer_id_nulls,
    SUM(CASE WHEN total_orders_placed        IS NULL THEN 1 ELSE 0 END) AS total_orders_nulls,
    SUM(CASE WHEN latest_order_status        IS NULL THEN 1 ELSE 0 END) AS latest_status_nulls,
    SUM(CASE WHEN latest_review_score        IS NULL THEN 1 ELSE 0 END) AS latest_review_score_nulls,     -- expected: customers with no reviews
    SUM(CASE WHEN lifetime_avg_review_score  IS NULL THEN 1 ELSE 0 END) AS avg_review_score_nulls,        -- expected: same reason
    SUM(CASE WHEN first_purchase_date        IS NULL THEN 1 ELSE 0 END) AS first_purchase_nulls,
    SUM(CASE WHEN latest_order_date          IS NULL THEN 1 ELSE 0 END) AS latest_order_date_nulls,
    SUM(CASE WHEN customer_zip_code          IS NULL THEN 1 ELSE 0 END) AS zip_code_nulls,
    SUM(CASE WHEN customer_state             IS NULL THEN 1 ELSE 0 END) AS state_nulls,                   -- should be 0 post city/state fix
    SUM(CASE WHEN customer_city              IS NULL THEN 1 ELSE 0 END) AS city_nulls,                    -- should be 0 post city/state fix
    SUM(CASE WHEN customer_lat               IS NULL THEN 1 ELSE 0 END) AS lat_nulls,                     -- expected: genuine geoloc source gap, not fallback-handled
    SUM(CASE WHEN customer_lng               IS NULL THEN 1 ELSE 0 END) AS lng_nulls                      -- expected: same reason
FROM gold.dim_customer;

PRINT 'Check: fact_sales null audit...';
SELECT
    SUM(CASE WHEN order_id                       IS NULL THEN 1 ELSE 0 END) AS order_id_nulls,
    SUM(CASE WHEN product_id                     IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
    SUM(CASE WHEN seller_id                      IS NULL THEN 1 ELSE 0 END) AS seller_id_nulls,
    SUM(CASE WHEN customer_id                    IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
    SUM(CASE WHEN customer_unique_id             IS NULL THEN 1 ELSE 0 END) AS customer_unique_id_nulls,
    SUM(CASE WHEN order_status                   IS NULL THEN 1 ELSE 0 END) AS order_status_nulls,
    SUM(CASE WHEN item_price                     IS NULL THEN 1 ELSE 0 END) AS item_price_nulls,
    SUM(CASE WHEN freight_value                  IS NULL THEN 1 ELSE 0 END) AS freight_value_nulls,
    SUM(CASE WHEN total_order_payment            IS NULL THEN 1 ELSE 0 END) AS total_payment_nulls,        -- COALESCE fallback — should be 0
    SUM(CASE WHEN avg_review_score               IS NULL THEN 1 ELSE 0 END) AS avg_review_score_nulls,     -- COALESCE fallback — should be 0
    SUM(CASE WHEN order_purchase_timestamp       IS NULL THEN 1 ELSE 0 END) AS purchase_ts_nulls,
    SUM(CASE WHEN order_estimated_delivery_date  IS NULL THEN 1 ELSE 0 END) AS estimated_delivery_nulls,
    SUM(CASE WHEN order_delivered_customer_date  IS NULL THEN 1 ELSE 0 END) AS delivered_date_nulls         -- expected: undelivered/cancelled orders
FROM gold.fact_sales;

PRINT 'Check: dim_review null audit...';
SELECT
    SUM(CASE WHEN review_id                      IS NULL THEN 1 ELSE 0 END) AS review_id_nulls,
    SUM(CASE WHEN order_id                       IS NULL THEN 1 ELSE 0 END) AS order_id_nulls,              -- should be 0 post order_id fix
    SUM(CASE WHEN product_id                     IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,            -- expected: orders with no matching item row
    SUM(CASE WHEN product_category_name_english  IS NULL THEN 1 ELSE 0 END) AS category_english_nulls,      -- expected: category with no translation row
    SUM(CASE WHEN review_score                   IS NULL THEN 1 ELSE 0 END) AS review_score_nulls,
    SUM(CASE WHEN review_title                   IS NULL THEN 1 ELSE 0 END) AS review_title_nulls,          -- COALESCE fallback — should be 0
    SUM(CASE WHEN review_message                 IS NULL THEN 1 ELSE 0 END) AS review_message_nulls,        -- COALESCE fallback — should be 0
    SUM(CASE WHEN review_creation_date           IS NULL THEN 1 ELSE 0 END) AS creation_date_nulls,
    SUM(CASE WHEN review_answer_timestamp        IS NULL THEN 1 ELSE 0 END) AS answer_timestamp_nulls
FROM gold.dim_review;

PRINT 'Check: dim_seller null audit...';
SELECT
    SUM(CASE WHEN seller_id       IS NULL THEN 1 ELSE 0 END) AS seller_id_nulls,
    SUM(CASE WHEN seller_zip_code IS NULL THEN 1 ELSE 0 END) AS zip_code_nulls,
    SUM(CASE WHEN seller_city     IS NULL THEN 1 ELSE 0 END) AS city_nulls,   -- expected: zip prefix with no geoloc match
    SUM(CASE WHEN seller_state    IS NULL THEN 1 ELSE 0 END) AS state_nulls   -- expected: same reason
FROM gold.dim_seller;

PRINT 'Check: dim_product null audit...';
SELECT
    SUM(CASE WHEN product_id           IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
    SUM(CASE WHEN product_category     IS NULL THEN 1 ELSE 0 END) AS category_nulls,        -- COALESCE fallback — should be 0
    SUM(CASE WHEN product_name_length  IS NULL THEN 1 ELSE 0 END) AS name_length_nulls,
    SUM(CASE WHEN product_desc_length  IS NULL THEN 1 ELSE 0 END) AS desc_length_nulls,
    SUM(CASE WHEN product_photos_count IS NULL THEN 1 ELSE 0 END) AS photos_count_nulls,
    SUM(CASE WHEN product_weight_grams IS NULL THEN 1 ELSE 0 END) AS weight_nulls
FROM gold.dim_product;
GO


-- ============================================================================
-- SECTION 4: REFERENTIAL INTEGRITY CHECKS
-- ============================================================================

PRINT 'Check: fact_sales product references missing from dim_product...';
-- Expectation: unmapped_product_count = 0 (100% catalog coverage)
SELECT
    COUNT(DISTINCT f.product_id) AS unmapped_product_count,
    COUNT(f.order_id) AS impacted_sales_lines
FROM gold.fact_sales f
LEFT JOIN gold.dim_product p
    ON f.product_id = p.product_id
WHERE p.product_id IS NULL;


PRINT 'Check: dim_review order_id source tracing...';
-- Distinguishes three separate scenarios that can all look like "missing
-- order_id" if only checked at the Gold layer:
--   1. The review itself never had an order_id at the source
--   2. The order exists in arc_ord_info but not arc_ord_item_info
--   3. The order doesn't exist in arc_ord_info at all
SELECT COUNT(*) AS source_null_order_ids
FROM silver.arc_ord_rvew_info
WHERE order_id IS NULL;

SELECT COUNT(*) AS orphaned_from_items
FROM silver.arc_ord_rvew_info rv
LEFT JOIN silver.arc_ord_item_info oif ON rv.order_id = oif.order_id
WHERE rv.order_id IS NOT NULL AND oif.order_id IS NULL;

SELECT COUNT(*) AS orphaned_from_orders
FROM silver.arc_ord_rvew_info rv
LEFT JOIN silver.arc_ord_info oi ON rv.order_id = oi.order_id
WHERE rv.order_id IS NOT NULL AND oi.order_id IS NULL;
GO


-- ============================================================================
-- SECTION 5: CHRONOLOGICAL & METRIC SANITY AUDITS
-- ============================================================================

PRINT 'Check: delivery dates never precede purchase timestamps...';
-- Expectation: 0 (or a negligible count of exceptional rows to filter in BI)
SELECT COUNT(*) AS broken_timeline_rows
FROM gold.fact_sales
WHERE order_delivered_customer_date < order_purchase_timestamp;


PRINT 'Check: review score domain boundaries (1.0-5.0)...';
-- FIXED: original version joined dim_customer and fact_sales with a comma
-- and no ON condition — an unintentional CROSS JOIN that would have
-- generated roughly 10.8 billion rows (96,350 x 112,650) before
-- aggregating. Split into two independent queries instead — same result,
-- no Cartesian explosion.
-- Expectation: all minimums >= 1.0 (or 0 if a customer has never reviewed),
-- all maximums <= 5.0
SELECT
    MIN(lifetime_avg_review_score) AS min_dim_score,
    MAX(lifetime_avg_review_score) AS max_dim_score
FROM gold.dim_customer;

SELECT
    MIN(avg_review_score) AS min_fact_score,
    MAX(avg_review_score) AS max_fact_score
FROM gold.fact_sales;
GO


-- ============================================================================
-- SECTION 6: FINANCIAL & VOLUME BASELINE (informational, not pass/fail)
-- ============================================================================

PRINT 'Baseline: revenue and volume scale check...';
-- Not a strict pass/fail test — a baseline snapshot to compare against
-- Silver-layer totals and sanity-check nothing collapsed or exploded
-- during the Gold transformation.
SELECT
    COUNT(DISTINCT order_id) AS total_unique_orders,
    COUNT(*) AS total_line_items,
    SUM(item_price) AS calculated_gross_merchandise_value,
    AVG(item_price) AS average_item_transaction_value
FROM gold.fact_sales;
GO


-- ============================================================================
-- SECTION 7: SOURCE DATA GAP AUDITS
-- ============================================================================

PRINT 'Audit: unique key volume diagnostics...';
SELECT 'Unique Customers' AS metric, COUNT(DISTINCT customer_unique_id) AS total FROM gold.dim_customer
UNION ALL
SELECT 'Unique Products', COUNT(DISTINCT product_id) FROM gold.dim_product
UNION ALL
SELECT 'Unique Sellers', COUNT(DISTINCT seller_id) FROM gold.dim_seller
UNION ALL
SELECT 'Total Sales Lines', COUNT(*) FROM gold.fact_sales;


PRINT 'Audit: postal code / geolocation coverage gap...';
-- Isolates customer zip prefixes with no matching row in the geolocation
-- table. NOTE: since the dim_customer fix, this gap only affects
-- customer_lat/customer_lng — city and state are sourced directly from
-- arc_cust_info now and are unaffected by this join. lat/lng nulls here
-- are a genuine, accepted source data gap — not fallback-handled.
SELECT
    cf.customer_zip_code_prefix,
    COUNT(DISTINCT cf.customer_unique_id) AS impacted_customers
FROM silver.arc_cust_info cf
LEFT JOIN silver.arc_geoloc_info gf
    ON cf.customer_zip_code_prefix = gf.geolocation_zip_code_prefix
WHERE gf.geolocation_zip_code_prefix IS NULL
GROUP BY cf.customer_zip_code_prefix;
GO
