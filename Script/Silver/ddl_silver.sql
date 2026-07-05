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


IF OBJECT_ID('silver.arc_cust_info' , 'U') IS NOT NULL
    DROP TABLE  silver.arc_cust_info;

CREATE TABLE silver.arc_cust_info(
    customer_id           VARCHAR(50) PRIMARY KEY,
    customer_unique_id    VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city         VARCHAR(100),
    customer_state        CHAR(2),
    dwn_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.arc_geoloc_info' , 'U') IS NOT NULL
    DROP TABLE  silver.arc_geoloc_info;

CREATE TABLE silver.arc_geoloc_info(
   geolocation_zip_code_prefix INT,
   geolocation_lat             DECIMAL(10, 8),
   geolocation_lng             DECIMAL(11, 8),
   geolocation_city            NVARCHAR(100),
   geolocation_state           CHAR(2),
       dwn_create_date DATETIME2 DEFAULT GETDATE()
    );


    IF OBJECT_ID('silver.arc_ord_item_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_ord_item_info;

    CREATE TABLE silver.arc_ord_item_info(
      order_id              VARCHAR(100),
      order_item_id         INT,
      product_id            VARCHAR(100),
      seller_id             VARCHAR(100),
      shipping_limit_date   DATETIME,
      price                 DECIMAL(10, 2),
      freight_value         DECIMAL(10, 2),
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );

    IF OBJECT_ID('silver.arc_payment_info' , 'U') IS NOT NULL
        DROP TABLE silver.arc_payment_info;

    CREATE TABLE silver.arc_payment_info (
        order_id             VARCHAR(50) NOT NULL,
        payment_sequential   INT,
        payment_type         VARCHAR(50),
        payment_installments INT,
        payment_value        DECIMAL(10, 2), -- Maintains exact financial accuracy
        dwn_create_date      DATETIME2 DEFAULT GETDATE()
    );


    IF OBJECT_ID('silver.arc_ord_rvew_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_ord_rvew_info;

    CREATE TABLE silver.arc_ord_rvew_info(
        review_id                  VARCHAR(50),
        order_id                   VARCHAR(50),
        review_score               INT,
        review_comment_title       NVARCHAR(200),
        review_comment_message     NVARCHAR(MAX),
        review_creation_date       DATETIME,
        review_answer_timestamp    DATETIME,
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );

    IF OBJECT_ID('silver.arc_ord_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_ord_info;

    CREATE TABLE silver.arc_ord_info(
        order_id                        VARCHAR(50),
        customer_id                     NVARCHAR(100),
        order_status                    VARCHAR(50),
        order_purchase_timestamp        DATETIME,
        order_approved_at               DATETIME,
        order_delivered_carrier_date    DATETIME,
        order_delivered_customer_date   DATETIME,
        order_estimated_delivery_date   DATETIME,
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );

    IF OBJECT_ID('silver.arc_prduct_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_prduct_info;

    CREATE TABLE silver.arc_prduct_info(
        product_id                 VARCHAR(50),
        product_category_name      NVARCHAR(50),
        product_name_lenght         INT,
        product_description_lenght  INT,
        product_photos_qty          INT,
        product_weight_g            INT,
        product_length_cm           INT,
        product_height_cm           INT,
        product_width_cm            INT,
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );

    IF OBJECT_ID('silver.arc_seler_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_seler_info;

    CREATE TABLE silver.arc_seler_info(
        seller_id                     VARCHAR(50),
        seller_zip_code_prefix        INT,
        seller_city                   NVARCHAR(100),
        seller_state                  CHAR(2),
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );

    IF OBJECT_ID('silver.arc_prdt_ctr_nme_info' , 'U') IS NOT NULL
        DROP TABLE  silver.arc_prdt_ctr_nme_info;

    CREATE TABLE silver.arc_prdt_ctr_nme_info(
        product_category_name            NVARCHAR(100),
        product_category_name_english    NVARCHAR(100),
      dwn_create_date DATETIME2 DEFAULT GETDATE()
    );
END

END
