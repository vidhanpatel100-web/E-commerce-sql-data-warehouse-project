# E-Commerce SQL Data Warehouse Project

A full data warehouse built on the Olist Brazilian e-commerce dataset, using SQL Server and a Medallion (Bronze → Silver → Gold) architecture, with Tableau as the reporting layer on top.

This isn't a toy dataset cleaned up for a tutorial. Olist's real data is messy in the way real e-commerce data actually is — customer reviews with commas and line breaks inside the text, duplicate zip codes mapping to multiple lat/lng points, orders that don't cleanly map one-to-one with anything. A good chunk of this project was spent dealing with exactly that.

## Architecture

### High-level flow

<img width="1053" height="730" alt="image" src="https://github.com/user-attachments/assets/42db1b9c-82b6-4b21-babf-de38c9aa14cc" />


Raw CSVs land in an archive folder, get loaded into SQL Server, and move through three layers before reaching Tableau. Bronze is a straight batch load with no transformations — the point is to capture the data exactly as it arrived, not to clean it yet. Silver applies cleansing, standardization, normalization, and enrichment, still as plain tables. Gold is where it stops looking like a copy of the source system and starts looking like something a business question can be asked of — no separate load step here, since Gold is built as views computed live over Silver, structured as a star schema.

### Silver → Gold lineage

<img width="1285" height="707" alt="image" src="https://github.com/user-attachments/assets/a7eb1cf8-4d92-4d12-8f4e-5fb5c04dfbcb" />



Nine Bronze tables map one-to-one into nine Silver tables. From there, the fan-out starts: most Silver tables feed multiple Gold objects. `silver.arc_cust_info`, for instance, feeds both `gold.dim_customer` and `gold.fact_sales`, since customer identity shows up in both the dimension and every sales record. The lines in this diagram are really a map of every join in the Gold layer views — useful for tracing "if I change this Silver column, what breaks downstream."

### Star schema (Gold layer)

<img width="967" height="620" alt="image" src="https://github.com/user-attachments/assets/c1bc191c-b5ca-4d61-a58f-bab9d38d6a1d" />


`gold.fact_sales` sits at the center, at order-line-item grain, with foreign keys out to four dimensions:

- **`dim_customer`** — one row per person (`customer_unique_id`), not per order. Recency, frequency, and location fields all live here, which is what makes it usable directly for RFM segmentation.
- **`dim_product`** — category, dimensions, and weight per product.
- **`dim_seller`** — seller location, cleaned and deduplicated against the geolocation table.
- **`dim_review`** — review text and score. Worth calling out explicitly: reviews in the source data are captured per *order*, not per *product*, so this view isn't unique per `order_id` when an order contains multiple products from different categories. That's intentional (it enables category-level sentiment analysis) but means any review count in Tableau has to use a distinct count, not a plain row count.

### Source system integration model

<img width="1311" height="797" alt="image" src="https://github.com/user-attachments/assets/dff61290-244e-4abe-ab9f-4a2f25b82d89" />




This is the Silver-layer join map before anything gets aggregated into Gold — how `arc_cust_info`, `arc_ord_info`, `arc_ord_item_info`, `arc_ord_payment_info`, `arc_ord_rvew_info`, `arc_prduct_info`, `arc_seler_info`, and `arc_geoloc_info` actually connect to each other via `customer_id`, `order_id`, `product_id`, `seller_id`, and zip code prefix. This is the reference I went back to most often while debugging join fan-out issues during Gold layer development — it's worth keeping in the repo for exactly that reason, not just as documentation.

## What's actually in here

**Bronze layer** — raw ingestion, no transformations. The order reviews file in particular broke standard `BULK INSERT` outright, because customer comments contain embedded commas and newlines that a naive comma-delimited parser tears apart. Fixed with a pure T-SQL blob-and-parse approach: load the whole file as one column, then walk it with a quote-aware scanner before splitting into rows. No Python, no external tools — SQL Server end to end, which was a deliberate constraint, not a limitation I ran into by accident.

**Silver layer** — cleansing, standardization, deduplication, null handling. Every table here got run through a validation pass: primary key duplicate checks, null audits, whitespace checks, referential integrity between orders/items/products/sellers. Caught two real bugs during this: an order-items load that was accidentally running twice instead of loading payments, and a reviews load that was truncating the reviews table and then writing into the wrong table entirely, leaving it empty. Both are fixed, and the validation script that caught them is in this repo — it's not just decoration, it's what actually found the bugs.

**Gold layer** — a star schema: `dim_customer`, `dim_product`, `dim_seller`, `dim_review`, and `fact_sales` at order-line-item grain. Getting the customer dimension down to one row per person took a few iterations — the tricky part is that Olist assigns a new `customer_id` per order, so "one row per person" means aggregating across every order a person has ever placed, correctly picking their *most recent* order status and address rather than just grabbing whatever `MAX()` happens to sort to alphabetically. There's a documented gotcha in `fact_sales` too: payment totals are stored at order grain but repeat across every line item in that order, so summing them directly without accounting for that will overcount — it's called out directly in the view's comments.

## Repo structure

```
Script/     -- SQL scripts: Bronze ingestion, Silver transforms, Gold views
datasets/   -- source CSVs (Olist public dataset)
docs/       -- architecture notes, KPI/dashboard planning
tests/      -- data quality validation scripts (null checks, dedup checks, referential integrity)
```


## Dataset

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — 99,441 customers, 112,650 order line items, 99,224 reviews, 32,951 products, 3,095 sellers, spanning 2016–2018.

## Running it

1. Restore the Olist CSVs into a SQL Server instance (paths are parameterized at the top of each ingestion script — update before running).
2. Run the Bronze scripts to load raw data.
3. Run `silver.ecommerce_load_bronze` to transform Bronze into Silver.
4. Deploy the Gold layer views (`Script/gold_layer_star_schema.sql`).
5. Run the validation scripts in `tests/` to confirm row counts and data quality before connecting anything to Tableau.

## Power BI Dashboards

The reporting layer is fully built using Power BI, connecting directly to the analytical views in the Gold layer. The suite is broken down into four distinct strategic views:

- **Core Business KPIs:** Macro revenue tracking, transaction volume, and product performance by cost brackets.
- **Retention & RFM Strategy:** Precision customer behavioral cohort clustering (VIP Loyalists, Newbies, Standard Active, and One-Time Churned) to monitor long-term audience value.
- **Geographic Insights:** Map-based supply and demand distributions tracking international seller density vs. regional customer concentration.
- **Logistics & Sentiment:** A core deep-dive analyzing operations impact, proving a clear mathematical correlation between extreme shipping latency (including a massive 188-day outlier) and plummeting customer review scores.

### Interactive Dashboard Walkthrough
https://github.com/vidhanpatel100-web/E-commerce-sql-data-warehouse-project/blob/main/power_bi%20dashboard-compressed.mp4

## Status

**Complete & Validated.** The end-to-end architecture is fully functional. The repository hosts the complete lineage from raw Bronze storage, Silver cleaning routines, Gold dimensional modeling views, and the final analytical Power BI asset layout
## License

## Breakdown explanation

https://marketingbrain1.substack.com/p/ecommerce-vip-retention-rfm-analysis?r=3g34oc

MIT — see `LICENSE`.
