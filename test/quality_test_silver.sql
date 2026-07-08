/* =====================================================================
   SILVER LAYER — DATA QUALITY VALIDATION
   E-Commerce Data Warehouse | SQL Server
   =====================================================================
   Convention: each check states its expected result as a comment
   directly above the query. A check "passing" means it returns the
   stated result.

   Note: a few checks below verify the OUTPUT of transformations that
   already ran inside silver.ecommerce_load_bronze (Title Case order
   status, geolocation city symbol-stripping). These are validation
   checks confirming the transform worked, not the transforms themselves.
   ===================================================================== */


/* =====================================================================
   1. CUSTOMERS  (silver.arc_cust_info)
   ===================================================================== */

-- Check: Duplicate customer_id
-- Expectation: No rows returned
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM silver.arc_cust_info
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check: Duplicate customer_unique_id
-- Expectation: No rows returned
SELECT
    customer_unique_id,
    COUNT(*) AS duplicate_count
FROM silver.arc_cust_info
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Check: Inconsistent casing / formatting in customer_city
-- Expectation: Manual review — flags inconsistent capitalization
-- or unexpected string lengths
SELECT DISTINCT
    customer_city,
    LEN(customer_city) AS string_length
FROM silver.arc_cust_info
ORDER BY customer_city;


/* =====================================================================
   2. GEOLOCATION  (silver.arc_geoloc_info)
   ===================================================================== */

-- Check: Lat/Lng coordinate integrity
-- Expectation: Min/Max fall within Brazil's real geographic bounds
-- (roughly Lat -33.75 to 5.27, Lng -73.99 to -34.79) — values outside
-- that range indicate a parsing or unit error upstream
SELECT
    MIN(geolocation_lat) AS min_lat,
    MAX(geolocation_lat) AS max_lat,
    MIN(geolocation_lng) AS min_lng,
    MAX(geolocation_lng) AS max_lng
FROM silver.arc_geoloc_info;

-- Check: Leading symbols/junk characters in geolocation_city
-- (validates the PATINDEX cleanup applied during the Silver load)
-- Expectation: 0 rows — every city name should start with a real
-- letter or digit, not a leading symbol
SELECT COUNT(*) AS cities_with_leading_symbols
FROM silver.arc_geoloc_info
WHERE PATINDEX('%[A-Za-z0-9]%', geolocation_city) > 1;

-- Check: Leading/trailing whitespace on city and state
-- Expectation: Both counts = 0
SELECT
    COUNT(CASE WHEN LEN(geolocation_city)  != LEN(TRIM(geolocation_city))  THEN 1 END) AS city_has_spaces,
    COUNT(CASE WHEN LEN(geolocation_state) != LEN(TRIM(geolocation_state)) THEN 1 END) AS state_has_spaces
FROM silver.arc_geoloc_info;

-- Check: Distinct state values
-- Expectation: Manual review — confirms only valid Brazilian state
-- codes are present, no stray characters or unexpected values
SELECT DISTINCT geolocation_state
FROM silver.arc_geoloc_info
ORDER BY geolocation_state;


/* =====================================================================
   3. ORDERS  (silver.arc_ord_info)
   ===================================================================== */

-- Check: Orders missing a carrier delivery date
-- Expectation: Review count — expected for cancelled/undelivered orders
SELECT *
FROM silver.arc_ord_info
WHERE order_delivered_carrier_date IS NULL;

-- Check: order_status formatting (validates the Title Case transform
-- applied during the Silver load)
-- Expectation: Manual review — every value should read as a single
-- Title Case word (e.g. 'Delivered', 'Shipped'), no all-caps or
-- all-lowercase stragglers
SELECT DISTINCT order_status
FROM silver.arc_ord_info
ORDER BY order_status;


/* =====================================================================
   4. ORDER ITEMS  (silver.arc_ord_item_info)
   ===================================================================== */

-- Check: Composite primary key (order_id + order_item_id) duplicates
-- Expectation: No rows returned
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM silver.arc_ord_item_info
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
FROM silver.arc_ord_item_info;

-- Check: Referential integrity — order items referencing a product
-- that does not exist in the products table
-- Expectation: orphaned_products = 0
SELECT COUNT(DISTINCT oi.product_id) AS orphaned_products
FROM silver.arc_ord_item_info oi
LEFT JOIN silver.arc_prduct_info p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Check: Shipping deadline coverage and range
-- Expectation: missing_shipping_deadlines = 0
SELECT
    COUNT(CASE WHEN shipping_limit_date IS NULL THEN 1 END) AS missing_shipping_deadlines,
    MIN(shipping_limit_date) AS earliest_deadline,
    MAX(shipping_limit_date) AS latest_deadline
FROM silver.arc_ord_item_info;


/* =====================================================================
   5. PRODUCTS  (silver.arc_prduct_info)
   ===================================================================== */

-- Check: Null counts across all product attributes
-- Expectation: category_nulls = 0 (COALESCE fallback applied at load —
-- see naming_conventions.md re: product_name_lenght spelling)
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

-- Check: product_category_name still null after COALESCE fallback
-- Expectation: 0 rows — Silver load should have replaced every null
-- with 'Uncategorized' already
SELECT product_category_name
FROM silver.arc_prduct_info
WHERE product_category_name IS NULL;


/* =====================================================================
   6. SELLERS  (silver.arc_seler_info)
   ===================================================================== */

-- Check: Duplicate seller_id
-- Expectation: No rows returned
SELECT
    seller_id,
    COUNT(*) AS duplicate_count
FROM silver.arc_seler_info
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Check: Null counts across all seller attributes
-- Expectation: All columns = 0
SELECT
    SUM(CASE WHEN seller_id              IS NULL THEN 1 ELSE 0 END) AS seller_id_nulls,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS zip_code_nulls,
    SUM(CASE WHEN seller_state           IS NULL THEN 1 ELSE 0 END) AS state_nulls,
    SUM(CASE WHEN seller_city            IS NULL THEN 1 ELSE 0 END) AS city_nulls
FROM silver.arc_seler_info;

-- Check: Leading/trailing whitespace in text fields
-- Expectation: All counts = 0
SELECT
    COUNT(CASE WHEN LEN(seller_id) != LEN(TRIM(seller_id)) THEN 1 END)       AS seller_id_has_spaces,
    COUNT(CASE WHEN LEN(seller_city) != LEN(TRIM(seller_city)) THEN 1 END)   AS city_has_spaces,
    COUNT(CASE WHEN LEN(seller_state) != LEN(TRIM(seller_state)) THEN 1 END) AS state_has_spaces
FROM silver.arc_seler_info;
