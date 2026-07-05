/*
===============================================================
DDL Script: Create Silver Tables
===============================================================

Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================
*/

EXEC silver.ecommerce_load_bronze;

CREATE OR ALTER PROCEDURE silver.ecommerce_load_bronze AS

BEGIN

DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
BEGIN TRY
SET @batch_start_time = GETDATE();
PRINT '=================================================='
PRINT 'Loading Silver Layer'
PRINT '=================================================='

    -- 1. Ingest Customers Dataset

    SET @start_time = GETDATE();
    PRINT '>> Truncating Table: silver.arc_cust_info'

    TRUNCATE TABLE silver.arc_cust_info;

    PRINT '>> Inserting Table: silver.arc_cust_info'

      INSERT INTO silver.arc_cust_info(
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state)

      SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state
      FROM bronze.arc_cust_info
            

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
     PRINT '>> ------------ ';

    -- 2. Ingest Geolocation Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_geoloc_info'

    TRUNCATE TABLE silver.arc_geoloc_info;

    PRINT '>> Inserting Table: silver.arc_geoloc_info'

        INSERT INTO  silver.arc_geoloc_info(
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
        )

        SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
            -- FIXED: Finds where the first real alphanumeric letter OR digit starts
            TRIM(
                SUBSTRING(
                    geolocation_city,
                    PATINDEX('%[A-Za-z0-9]%', geolocation_city), -- Added 0-9 here!
                    LEN(geolocation_city)
                )
            ) AS geolocation_cty,
        geolocation_state
        FROM bronze.arc_geoloc_info; 


    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 3. Ingest Orders Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_ord_info'

    TRUNCATE TABLE silver.arc_ord_info;

    PRINT '>> Inserting Table: silver.arc_ord_info'

            INSERT INTO silver.arc_ord_info (order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date)
 
            SELECT 
            order_id,
            customer_id,
            -- Applies clean Title Case formatting
                UPPER(LEFT(TRIM(order_status), 1)) + 
                LOWER(SUBSTRING(TRIM(order_status), 2, LEN(order_status))) AS order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date
            FROM bronze.arc_ord_info 

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 4. Ingest Order Items Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_ord_item_info'

    TRUNCATE TABLE silver.arc_ord_item_info;

    PRINT '>> Inserting Table: silver.arc_ord_item_info'

    
            INSERT INTO silver.arc_ord_item_info (order_id,
                order_item_id,
                product_id,
                seller_id,
                shipping_limit_date,
                price,
                freight_value)
 
            SELECT 
                order_id,
                order_item_id,
                product_id,
                seller_id,
                shipping_limit_date,
                price,
                freight_value
            FROM bronze.arc_ord_item_info

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 5. Ingest Order Payments Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_ord_item_info '

    TRUNCATE TABLE silver.arc_ord_item_info ;

    PRINT '>> Inserting Table: silver.arc_ord_item_info' 

    
       INSERT INTO silver.arc_ord_item_info (order_id,
            order_item_id,
            product_id,
            seller_id,
            shipping_limit_date,
            price,
            freight_value)
 
        SELECT 
            order_id,
            order_item_id,
            product_id,
            seller_id,
            shipping_limit_date,
            price,
            freight_value
        FROM bronze.arc_ord_item_info

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 6. Ingest Order Reviews Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_ord_rvew_info'
        
    TRUNCATE TABLE silver.arc_ord_rvew_info;

    PRINT '>> Inserting Table: silver.arc_ord_rvew_info'
    
               INSERT INTO silver.arc_ord_item_info (
                order_id,
                order_item_id,
                product_id,
                seller_id,
                shipping_limit_date,
                price,
                freight_value
            )
            SELECT 
                TRIM(order_id) AS order_id,
                TRY_CAST(order_item_id AS INT) AS order_item_id,
                TRIM(product_id) AS product_id,
                TRIM(seller_id) AS seller_id,
                TRY_CAST(shipping_limit_date AS DATETIME2) AS shipping_limit_date,
                TRY_CAST(price AS DECIMAL(10,2)) AS price,
                TRY_CAST(freight_value AS DECIMAL(10,2)) AS freight_value
            FROM bronze.arc_ord_item_info
                   
    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 7. Ingest Products Catalog Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_prduct_info'

    TRUNCATE TABLE silver.arc_prduct_info;

    PRINT '>> Inserting Table: silver.arc_prduct_info'

            INSERT INTO silver.arc_prduct_info(
            product_id,
            product_category_name,
            product_name_lenght,
            product_description_lenght,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        )
        SELECT
            product_id,
            product_category_name,
            product_name_lenght,
            product_description_lenght,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        FROM(
            SELECT
                product_id,
                -- Swaps blank text records with 'Uncategorized'
                COALESCE(product_category_name, 'Uncategorized') AS product_category_name,
                -- Swaps blank numeric fields with 0
                COALESCE(product_name_lenght, 0) AS product_name_lenght,
                COALESCE(product_description_lenght, 0) AS product_description_lenght,
                COALESCE(product_photos_qty, 0) AS product_photos_qty,
                COALESCE(product_weight_g, 0) AS product_weight_g,
                COALESCE(product_length_cm, 0) AS product_length_cm,
                COALESCE(product_height_cm, 0) AS product_height_cm,
                COALESCE(product_width_cm, 0) AS product_width_cm,

                -- Ensures unique rows per product_id
                ROW_NUMBER() OVER(
                    PARTITION BY product_id
                    ORDER BY product_weight_g DESC
                ) AS row_num
            FROM bronze.arc_prduct_info
            WHERE product_id IS NOT NULL
        ) T
        WHERE row_num = 1;

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 8. Ingest Sellers Merchant Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_seler_info'

    TRUNCATE TABLE silver.arc_seler_info;

    PRINT '>> Inserting Table: silver.arc_seler_info'

    INSERT INTO silver.arc_seler_info(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
        )
        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state
        FROM bronze.arc_seler_info;

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 9. Ingest Product Category Translation Map
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.arc_prdt_ctr_nme_info'

    TRUNCATE TABLE silver.arc_prdt_ctr_nme_info;

    PRINT '>> Inserting Table: silver.arc_prdt_ctr_nme_info'
        
        INSERT INTO silver.arc_prdt_ctr_nme_info (
             product_category_name,
             product_category_name_english)
        SELECT
             product_category_name,
             product_category_name_english
        FROM bronze.arc_prdt_ctr_nme_info

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    SET @batch_end_time = GETDATE();
     PRINT '=================================================='
    PRINT 'Loading Silver Layer is Completed'
    PRINT '   -- Total Load Duration: ' + CAST(DATEDIFF(ss, @batch_start_time, @batch_end_time) AS NVARCHAR) + 'sec';
    PRINT '=================================================='

    END TRY
    BEGIN CATCH
    PRINT '=================================================='
    PRINT 'ERROR OCCURED DURING BRONZE LAYER'
    PRINT 'Error Message' + ERROR_MESSAGE();
    PRINT 'Error Message' + CAST(ERROR_NUMBER() AS VARCHAR);
    PRINT '=================================================='
    END CATCH

END
