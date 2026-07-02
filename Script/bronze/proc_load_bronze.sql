/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the 'BULK INSERT' command to load data from CSV files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.ecommerce_load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.ecommerce_load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '==================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '==================================================';

        -- ===================================================================
        -- 1. Ingest Customers Dataset
        -- ===================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.arc_cust_info';
        TRUNCATE TABLE bronze.arc_cust_info;

        PRINT '>> Inserting Table: bronze.arc_cust_info';
        BULK INSERT bronze.arc_cust_info
        FROM 'E:\E-commerce data\archive\olist_customers_dataset.csv'
        WITH(
            FIRSTROW = 2,
            FORMAT = 'CSV',
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            ROWTERMINATOR = '0x0a',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR(10)) + ' sec';
        PRINT '>> ------------ ';

        -- ===================================================================
        -- 2. Ingest Geolocation Dataset
        -- ===================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.arc_geoloc_info';
        TRUNCATE TABLE bronze.arc_geoloc_info;

        PRINT '>> Inserting Table: bronze.arc_geoloc_info';
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
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR(10)) + ' sec';
        PRINT '>> ------------ ';

        -- ===================================================================
        -- 3. Ingest Orders Dataset (Using Staging Fix to Prevent Empty Date Crashes)
        -- ===================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.arc_ord_info';
        
        DROP TABLE IF EXISTS #temp_orders;
        CREATE TABLE #temp_orders (
            order_id VARCHAR(50), customer_id VARCHAR(50), order_status VARCHAR(50),
            order_purchase_timestamp VARCHAR(50), order_approved_at VARCHAR(50),
            order_delivered_carrier_date VARCHAR(50), order_delivered_customer_date VARCHAR(50),
            order_estimated_delivery_date VARCHAR(50)
        );

        PRINT '>> Inserting Table: bronze.arc_ord_info (via Staging Layer)';
        BULK INSERT #temp_orders
        FROM 'E:\E-commerce data\archive\olist_orders_dataset.csv'
        WITH ( FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK );

        TRUNCATE TABLE bronze.arc_ord_info;
        INSERT INTO bronze.arc_ord_info (
            order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at,
            order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date
        )
        SELECT 
            REPLACE(order_id, '"', ''), REPLACE(customer_id, '"', ''), REPLACE(order_status, '"', ''),
            TRY_CAST(NULLIF(REPLACE(order_purchase_timestamp, '"', ''), '') AS DATETIME),
            TRY_CAST(NULLIF(REPLACE(order_approved_at, '"', ''), '') AS DATETIME),
            TRY_CAST(NULLIF(REPLACE(order_delivered_carrier_date, '"', ''), '') AS DATETIME),
            TRY_CAST(NULLIF(REPLACE(order_delivered_customer_date, '"', ''), '') AS DATETIME),
            TRY_CAST(NULLIF(REPLACE(order_estimated_delivery_date, '"', ''), '') AS DATETIME)
        FROM #temp_orders;
        DROP TABLE #temp_orders;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR(10)) + ' sec';
        PRINT '>> ------------ ';

        -- ===================================================================
        -- 4. Ingest Order Items Dataset
        -- ===================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.arc_ord_item_info';
        TRUNCATE TABLE bronze.arc_ord_item_info;

        PRINT '>> Inserting Table: bronze.arc_ord_item_info';
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
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR(10)) + ' sec';
        PRINT '>> ------------ ';

        -- ===================================================================
        -- 5. Ingest Order Payments Dataset
        -- ===================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.arc_ord_payment_info';
        TRUNCATE TABLE bronze.arc_ord_payment_info;

        PRINT '>> Inserting Table: bronze.arc_ord_payment_info';
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
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(ss, @start_time, @end_time) AS VARCHAR(10)) + ' sec';
        PRINT '>> ------------ ';

        -- ===================================================================
        -- 6. Ingest Order Reviews Dataset (Flexible Staging Text Sponge)
        -- ===================================================================
        SET @start_time = GETDATE();
        
        DROP TABLE IF EXISTS #temp_reviews;
        CREATE TABLE #temp_reviews (
            review_id               VARCHAR(MAX),
            order_id                VARCHAR(MAX),
            review_score            VARCHAR(MAX),
            review_comment_title    NVARCHAR(MAX),
            review_comment_message  N
