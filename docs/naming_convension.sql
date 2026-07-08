# Naming Conventions

## Overview

This document defines the naming rules used across all three layers of the warehouse (Bronze, Silver, Gold), so any table or column name can be decoded without needing to open the object itself.

---

## Schema Layers

| Schema | Purpose |
|---|---|
| `bronze` | Raw data, loaded as-is from source CSVs. No renaming beyond the table prefix convention below. |
| `silver` | Cleansed and standardized data. Same table names as Bronze — only the schema changes. |
| `gold` | Business-ready views. Different naming convention entirely — see below. |

---

## Bronze / Silver Table Naming

Pattern: `arc_<entity>_info`

`arc` stands for **archive** — signaling these are raw/near-raw captures of source system data, not business-modeled objects. Entity names are abbreviated to keep table names short; the full glossary is below.

| Table | Full Meaning |
|---|---|
| `arc_cust_info` | Customers |
| `arc_ord_info` | Orders |
| `arc_ord_item_info` | Order Line Items |
| `arc_ord_payment_info` | Order Payments |
| `arc_ord_rvew_info` | Order Reviews |
| `arc_prduct_info` | Products |
| `arc_seler_info` | Sellers |
| `arc_geoloc_info` | Geolocation |
| `arc_prdt_ctr_nme_info` | Product Category Name (translation map) |

---

## Gold Layer Naming

Pattern: `dim_<entity>` for dimension views, `fact_<entity>` for fact views — standard star schema convention, chosen deliberately to break from the Bronze/Silver `arc_` pattern so it's immediately obvious which layer an object belongs to just from its name.

| Object | Type | Grain |
|---|---|---|
| `gold.dim_customer` | Dimension | One row per person (`customer_unique_id`) |
| `gold.dim_product` | Dimension | One row per product |
| `gold.dim_seller` | Dimension | One row per seller |
| `gold.dim_review` | Dimension | One row per (order, product) pairing — see `data_catalog.md` for the grain caveat |
| `gold.fact_sales` | Fact | One row per order line item |

---

## Column Naming Rules

- All columns use `snake_case`, no exceptions.
- Bronze/Silver columns generally keep the source system's original names (including any misspellings present in the raw Olist data, e.g. `product_name_lenght` instead of `length` — this is intentional, not a typo introduced by this project, and is called out explicitly wherever it appears).
- Gold layer columns are renamed to be self-explanatory and consistent, even where the underlying Silver column name was abbreviated or inconsistent. Example: Silver's `product_name_lenght` becomes Gold's `product_name_length` — correctly spelled, since Gold is meant to be read by business users and BI tools, not just engineers who already know the source system's quirks.
- Foreign key columns in `fact_sales` use the exact same name as the dimension's primary key (`product_id`, `seller_id`, `customer_unique_id`) so joins in Tableau are unambiguous.

---

## Abbreviation Glossary

| Abbreviation | Full Term |
|---|---|
| `cust` | Customer |
| `ord` | Order |
| `rvew` | Review |
| `prduct` / `prdt` | Product |
| `seler` | Seller |
| `geoloc` | Geolocation |
| `ctr_nme` | Category Name |
| `arc` | Archive (Bronze/Silver prefix) |
| `dim` | Dimension (Gold prefix) |
| `fact` | Fact (Gold prefix) |
