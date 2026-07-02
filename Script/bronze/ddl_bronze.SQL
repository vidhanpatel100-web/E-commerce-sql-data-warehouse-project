/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates all the tracking and data staging tables within the 
    'bronze' schema layer. It safely drops existing tables if they already 
    exist to prevent structural deployment conflicts.
    
    Run this master file to re-define or initialize the core database blueprint.
===============================================================================
*/

EXEC bronze.ecommerce_load_bronze;

CREATE OR ALTER PROCEDURE bronze.ecommerce_load_bronze AS
BEGIN
DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
BEGIN TRY
SET @batch_start_time = GETDATE();
PRINT '=================================================='
PRINT 'Loading Bronze Layer'
PRINT '=================================================='

    -- 1. Ingest Customers Dataset

    SET @start_time = GETDATE();
    PRINT '>> Truncating Table: bronze.arc_cust_info'

    TRUNCATE TABLE bronze.arc_cust_info;

    PRINT '>> Inserting Table: bronze.arc_cust_info'

    BULK INSERT bronze.arc_cust_info
    FROM 'E:\E-commerce data\archive\olist_customers_dataset.csv' -- Added .csv extension
    WITH(
        FIRSTROW = 2,
        FORMAT = 'CSV',              -- Crucial for handling real CSV structures
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',            -- Strips out the quotation marks automatically
        ROWTERMINATOR = '0x0a',      -- Maps perfectly to your file's Unix (LF) format
        TABLOCK
    );
    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
     PRINT '>> ------------ ';


    -- 2. Ingest Geolocation Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_geoloc_info'

    TRUNCATE TABLE bronze.arc_geoloc_info;

    PRINT '>> Inserting Table: bronze.arc_geoloc_info'

    BULK INSERT bronze.arc_geoloc_info
    FROM 'E:\E-commerce data\archive\olist_geolocation_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';


    -- 3. Ingest Orders Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_ord_info'

    TRUNCATE TABLE bronze.arc_ord_info;

    PRINT '>> Inserting Table: bronze.arc_ord_info'

    BULK INSERT bronze.arc_ord_info
    FROM 'E:\E-commerce data\archive\olist_orders_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 4. Ingest Order Items Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_ord_item_info'

    TRUNCATE TABLE bronze.arc_ord_item_info;

    PRINT '>> Inserting Table: bronze.arc_ord_item_info'

    BULK INSERT bronze.arc_ord_item_info
    FROM 'E:\E-commerce data\archive\olist_order_items_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 5. Ingest Order Payments Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_ord_item_info'

    TRUNCATE TABLE bronze.arc_ord_payment_info;

    PRINT '>> Inserting Table: bronze.arc_ord_item_info'

    BULK INSERT bronze.arc_ord_payment_info
    FROM 'E:\E-commerce data\archive\olist_order_payments_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';


    -- 6. Ingest Order Reviews Dataset
    SET @start_time = GETDATE();

                -- STEP 1: Build the flexible staging sponge
                CREATE TABLE #temp_reviews (
                    review_id               VARCHAR(MAX),
                    order_id                VARCHAR(MAX),
                    review_score            VARCHAR(MAX),
                    review_comment_title    NVARCHAR(MAX),
                    review_comment_message  NVARCHAR(MAX),
                    review_creation_date    VARCHAR(MAX),
                    review_answer_timestamp VARCHAR(MAX)
                );

                -- STEP 2: Safe ingest of raw rows as raw text
                BULK INSERT #temp_reviews
                FROM 'E:\E-commerce data\archive\olist_order_reviews_dataset.csv'
                WITH (
                    FIRSTROW = 2,
                    FIELDTERMINATOR = ',',
                    ROWTERMINATOR = '0x0a',
                    TABLOCK
                );

                -- STEP 3: Clear old schema records
                PRINT '>> Truncating Table: bronze.arc_ord_rvew_info'

                TRUNCATE TABLE bronze.arc_ord_rvew_info;

                PRINT '>> Inserting Table: bronze.arc_ord_rvew_info'

                -- STEP 4: Safe, cleaned translation transfer with the 150-character buffer
                INSERT INTO bronze.arc_ord_rvew_info (
                    review_id,
                    order_id,
                    review_score,
                    review_comment_title,
                    review_comment_message,
                    review_creation_date,
                    review_answer_timestamp
                )
                SELECT
                    LEFT(REPLACE(review_id, '"', ''), 150),
                    LEFT(REPLACE(order_id, '"', ''), 150),
                    TRY_CAST(NULLIF(REPLACE(review_score, '"', ''), '') AS INT),
                    NULLIF(REPLACE(review_comment_title, '"', ''), ''),
                    NULLIF(REPLACE(review_comment_message, '"', ''), ''),
                    TRY_CAST(NULLIF(REPLACE(review_creation_date, '"', ''), '') AS DATETIME),
                    TRY_CAST(NULLIF(REPLACE(review_answer_timestamp, '"', ''), '') AS DATETIME)
                FROM #temp_reviews;

                -- STEP 5: Clear workspace memory
                DROP TABLE #temp_reviews

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 7. Ingest Products Catalog Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_prduct_info'

    TRUNCATE TABLE bronze.arc_prduct_info;

    PRINT '>> Inserting Table: bronze.arc_prduct_info'

    BULK INSERT bronze.arc_prduct_info
    FROM 'E:\E-commerce data\archive\olist_products_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 8. Ingest Sellers Merchant Dataset
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_seler_info'

    TRUNCATE TABLE bronze.arc_seler_info;

    PRINT '>> Inserting Table: bronze.arc_seler_info'

    BULK INSERT bronze.arc_seler_info
    FROM 'E:\E-commerce data\archive\olist_sellers_dataset.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    -- 9. Ingest Product Category Localization Translation Map
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: bronze.arc_prdt_ctr_nme_info'

    TRUNCATE TABLE bronze.arc_prdt_ctr_nme_info;

    PRINT '>> Inserting Table: bronze.arc_prdt_ctr_nme_info'

    BULK INSERT bronze.arc_prdt_ctr_nme_info
    FROM 'E:\E-commerce data\archive\product_category_name_translation.csv'
    WITH (
        FIRSTROW = 2,
        FORMAT = 'CSV',
        FIELDTERMINATOR = ',',
        FIELDQUOTE = '"',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR) + 'sec';
    PRINT '>> ------------ ';

    SET @batch_end_time = GETDATE();
     PRINT '=================================================='
    PRINT 'Loading Bronze Layer is Completed'
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
