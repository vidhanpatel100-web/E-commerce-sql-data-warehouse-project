# Data Dictionary for Gold Layer

## Overview

The Gold Layer is the business-level representation of the data, structured as a star schema for analytical and reporting use. It consists of four dimension views and one fact view. All Gold objects are implemented as SQL views (not physical tables) — they compute live over the Silver layer, so there's no separate load step to keep in sync.

---

## 1. gold.dim_customer

**Purpose:** One row per unique person (`customer_unique_id`), aggregated across every order they've ever placed. "Latest" fields reflect their most recent order specifically, not an arbitrary pick.

| Column Name | Data Type | Description |
|---|---|---|
| `customer_unique_id` | NVARCHAR | Unique identifier for the person, consistent across all their orders. Grain of this table. |
| `latest_session_customer_id` | NVARCHAR | The order-specific `customer_id` tied to this person's most recent order (Olist assigns a new `customer_id` per order). |
| `total_orders_placed` | INT | Count of distinct orders placed by this person, across their full history. |
| `latest_order_status` | NVARCHAR | Status of the person's most recent order, determined by actual order timestamp, not alphabetical sort. |
| `latest_review_score` | INT | Highest review score (1–5) this person has left across any order. NULL if they've never left a review. |
| `lifetime_avg_review_score` | FLOAT | Average review score across all of this person's reviewed orders. NULL if never reviewed. |
| `first_purchase_date` | DATETIME | Timestamp of this person's earliest order. |
| `latest_order_date` | DATETIME | Timestamp of this person's most recent order. |
| `customer_zip_code` | NVARCHAR | Zip code prefix associated with the person's most recent order. |
| `customer_state` | NVARCHAR | State, sourced directly from the customer record (native source column, no lookup). |
| `customer_city` | NVARCHAR | City, sourced directly from the customer record (native source column, no lookup). |
| `customer_lat` | FLOAT | Latitude, resolved via zip code prefix against the geolocation table. NULL for zip prefixes with no geolocation match — a known gap in the source data. |
| `customer_lng` | FLOAT | Longitude, same resolution and same known gap as `customer_lat`. |

---

## 2. gold.fact_sales

**Purpose:** Transactional fact table at order line-item grain. One row per product per order.

| Column Name | Data Type | Description |
|---|---|---|
| `order_id` | NVARCHAR | Order identifier. Not unique in this table — repeats once per item in multi-item orders. |
| `product_id` | NVARCHAR | Product identifier for this specific line item. |
| `seller_id` | NVARCHAR | Seller who fulfilled this specific line item. |
| `customer_id` | NVARCHAR | Order-specific customer identifier. |
| `customer_unique_id` | NVARCHAR | Person-level identifier, joins to `dim_customer`. |
| `order_status` | NVARCHAR | Status of the order this item belongs to. |
| `item_price` | DECIMAL | Price of this specific line item. |
| `freight_value` | DECIMAL | Shipping cost allocated to this specific line item. |
| `total_order_payment` | DECIMAL | Total amount paid for the *entire order* — repeats across all items in that order. See grain caveat above. |
| `avg_review_score` | FLOAT | Average review score for the *entire order* — repeats across all items in that order. Safe to `AVG()`, not safe to `SUM()`. |
| `order_purchase_timestamp` | DATETIME | When the order was placed. |
| `order_estimated_delivery_date` | DATETIME | Estimated delivery date given at purchase. |
| `order_delivered_customer_date` | DATETIME | Actual delivery date. NULL for orders not yet delivered or cancelled — expected, not a data quality issue. |

---

## 3. gold.dim_review

**Purpose:** Review text and score detail, joined down to product level for category-level sentiment analysis.


| Column Name | Data Type | Description |
|---|---|---|
| `review_id` | NVARCHAR | Review identifier. Not unique in this view — see grain caveat above. |
| `order_id` | NVARCHAR | Order this review was left for. Always populated — sourced from the review record itself, not from a join that could fail. |
| `product_id` | NVARCHAR | Product this review row has been attached to. NULL for the small number of orders with no matching line-item record in Silver (a genuine source data gap, not a pipeline bug). |
| `product_category_name_english` | NVARCHAR | English category name for the attached product. NULL if the category has no translation row. |
| `review_score` | INT | Score from 1–5. |
| `review_title` | NVARCHAR | Review title. Falls back to `'No Title Provided'` — this field should never be NULL. |
| `review_message` | NVARCHAR(MAX) | Review body text. Falls back to `'No Written Comment'` — this field should never be NULL. |
| `review_creation_date` | DATETIME | When the review was submitted. |
| `review_answer_timestamp` | DATETIME | When the seller/platform responded to the review. |

---

## 4. gold.dim_seller

**Purpose:** Clean seller location reference.

| Column Name | Data Type | Description |
|---|---|---|
| `seller_id` | NVARCHAR | Unique seller identifier. Grain of this table. |
| `seller_zip_code` | NVARCHAR | Seller's zip code prefix. |
| `seller_city` | NVARCHAR | City, resolved via zip code prefix against the geolocation table. NULL for the small number of zip prefixes with no geolocation match. |
| `seller_state` | NVARCHAR | State, same resolution and same known gap as `seller_city`. |

---

## 5. gold.dim_product

**Purpose:** Clean product catalog with dimensions and category.

| Column Name | Data Type | Description |
|---|---|---|
| `product_id` | NVARCHAR | Unique product identifier. Grain of this table. |
| `product_category` | NVARCHAR | English category name. Falls back to `'Unknown/Uncategorized'` — this field should never be NULL. |
| `product_name_length` | INT | Character length of the product's listed name. |
| `product_desc_length` | INT | Character length of the product description. |
| `product_photos_count` | INT | Number of photos listed for the product. |
| `product_weight_grams` | INT | Product weight in grams. |
