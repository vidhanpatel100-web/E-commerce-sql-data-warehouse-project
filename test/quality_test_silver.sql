/* =====================================================================
   SILVER LAYER — DATA QUALITY VALIDATION
   E-Commerce Data Warehouse | SQL Server
   =====================================================================
   Purpose:
     Validate primary key integrity, null handling, data standardization,
     and referential integrity across the Bronze -> Silver transformation
     layer of the e-commerce warehouse.

   Convention:
     Each check states its expected result as a comment directly above
     the query. A check "passing" means it returns the stated result.
   ===================================================================== */


/* =====================================================================
   1. CUSTOMERS  (bronze.arc_cust_info)
   ===================================================================== */

-- Check: Duplicate customer_id
-- Expectation: No rows returned
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM bronze.arc_cust_info
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check: Duplicate customer_unique_id
-- Expectation: No rows returned
SELECT
    customer_unique_id,
    COUNT(*) AS duplicate_count
FROM bronze.arc_cust_info
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Check: Inconsistent casing / formatting in customer_city
-- Expectation: Manual review — flags inconsistent capitalization,
-- abbreviations, or unexpected string lengths
SELECT DISTINCT
    customer_city,
    LEN(customer_city) AS string_length
FROM bronze.arc_cust_info
ORDER BY customer_city;


/* =====================================================================
   2. ORDERS  (bronze.arc_ord_info)
   ===================================================================== */

-- Check: Orders missing a carrier delivery date
-- Expectation: Review count — expected for cancelled / undelivered orders
SELECT *
FROM bronze.arc_ord_info
WHERE order_delivered_carrier_date IS NULL;

-- Check: Distinct order_status values present in source
-- Expectation: Confirms the full set of statuses before standardizing
SELECT DISTINCT order_status
FROM bronze.arc_ord_info;

-- Transformation: Standardize order_status to Title Case
SELECT
    order_id,
    customer_id,
    UPPER(LEFT(TRIM(order_status), 1))
        + LOWER(SUBSTRING(TRIM(order_status), 2, LEN(order_status))) AS order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM bronze.arc_ord_info;


/* =====================================================================
   3. ORDER ITEMS  (bronze.arc_ord_item_info)
   ===================================================================== */

-- Check: Composite primary key (order_id + order_item_id) duplicates
-- Expectation: No rows returned
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM bronze.arc_ord_item_info
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Check: Financial integrity — negative or zero price/freight values
-- Expectation: Negative_Prices = 0, Negative_Freight = 0
-- (Zero_Prices / Free_Shipping_Count reviewed manually — may be legitimate)
SELECT
    COUNT(CASE WHEN price < 0 THEN 1 END)         AS negative_prices,
    COUNT(CASE WHEN price = 0 THEN 1 END)         AS zero_prices,
    COUNT(CASE WHEN freight_value < 0 THEN 1 END) AS negative_freight,
    COUNT(CASE WHEN freight_value = 0 THEN 1 END) AS free_shipping_count
FROM bronze.arc_ord_item_info;

-- Check: Referential integrity — order items referencing a product
-- that does not exist in the products table
-- Expectation: Orphaned_Products = 0
SELECT COUNT(DISTINCT oi.product_id) AS orphaned_products
FROM bronze.arc_ord_item_info oi
LEFT JOIN bronze.arc_prduct_info p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Check: Shipping deadline coverage and range
-- Expectation: Missing_Shipping_Deadlines = 0
SELECT
    COUNT(CASE WHEN shipping_limit_date IS NULL THEN 1 END) AS missing_shipping_deadlines,
    MIN(shipping_limit_date) AS earliest_deadline,
    MAX(shipping_limit_date) AS latest_deadline
FROM bronze.arc_ord_item_info;


/* =====================================================================
   4. PRODUCTS  (bronze.arc_prduct_info / silver.arc_prduct_info)
   ===================================================================== */

-- Check: Null counts across all product attributes (post Bronze->Silver load)
-- Expectation: Nulls only in columns intentionally left unresolved
SELECT
    SUM(CASE WHEN product_id                  IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
    SUM(CASE WHEN product_category_name       IS NULL THEN 1 ELSE 0 END) AS category_nulls,
    SUM(CASE WHEN product_name_lenght         IS NULL THEN 1 ELSE 0 END) AS name_length_nulls,
    SUM(CASE WHEN product_description_lenght  IS NULL THEN 1 ELSE 0 END) AS description_length_nulls,
    SUM(CASE WHEN product_photos_qty          IS NULL THEN 1 ELSE 0 END) AS photos_qty_nulls,
    SUM(CASE WHEN product_weight_g            IS NULL THEN 1 ELSE 0 END) AS weight_nulls,
    SUM(CASE WHEN product_length_cm           IS NULL THEN 1 ELSE 0 END) AS length_nulls,
    SUM(CASE WHEN product_height_cm           IS NULL THEN 1 ELSE 0 END) AS height_nulls,
    SUM(CASE WHEN product_width_cm            IS NULL THEN 1 ELSE 0 END) AS width_nulls
FROM silver.arc_prduct_info;

-- Check: Rows with a missing product_category_name
-- Expectation: Confirms scope before applying the 'Uncategorized' fallback
SELECT
    product_category_name,
    COALESCE(product_category_name, 'Uncategorized') AS product_category_name_cleaned
FROM bronze.arc_prduct_info
WHERE product_category_name IS NULL;

-- Transformation: Cleanse product attributes
-- NOTE: bronze.arc_prduct_info uses the raw (misspelled) source column
-- names product_name_lenght / product_description_lenght. Confirm your
-- actual Bronze schema before running — use the *_lenght version below
-- if the table was loaded directly from the raw Olist column names.
SELECT
    COALESCE(product_category_name, 'Uncategorized') AS product_category_name,
    COALESCE(product_name_lenght, 0)        AS product_name_length,
    COALESCE(product_description_lenght, 0) AS product_description_length,
    COALESCE(product_photos_qty, 0)         AS product_photos_qty,
    COALESCE(product_weight_g, 0)           AS product_weight_g,
    COALESCE(product_length_cm, 0)          AS product_length_cm,
    COALESCE(product_height_cm, 0)          AS product_height_cm,
    COALESCE(product_width_cm, 0)           AS product_width_cm
FROM bronze.arc_prduct_info
WHERE product_name_lenght IS NULL;


/* =====================================================================
   5. SELLERS  (bronze.arc_seler_info)
   ===================================================================== */

-- Check: Duplicate seller_id
-- Expectation: No rows returned
SELECT
    seller_id,
    COUNT(*) AS duplicate_count
FROM bronze.arc_seler_info
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Check: Null counts across all seller attributes
-- Expectation: All columns = 0
SELECT
    SUM(CASE WHEN seller_id              IS NULL THEN 1 ELSE 0 END) AS seller_id_nulls,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS zip_code_nulls,
    SUM(CASE WHEN seller_state           IS NULL THEN 1 ELSE 0 END) AS state_nulls,
    SUM(CASE WHEN seller_city            IS NULL THEN 1 ELSE 0 END) AS city_nulls
FROM bronze.arc_seler_info;

-- Check: Leading/trailing whitespace in text fields
-- Expectation: All counts = 0
SELECT
    COUNT(CASE WHEN LEN(seller_id) != LEN(TRIM(seller_id)) THEN 1 END)       AS seller_id_has_spaces,
    COUNT(CASE WHEN LEN(seller_city) != LEN(TRIM(seller_city)) THEN 1 END)   AS city_has_spaces,
    COUNT(CASE WHEN LEN(seller_state) != LEN(TRIM(seller_state)) THEN 1 END) AS state_has_spaces
FROM bronze.arc_seler_info;
