# E-Commerce SQL Data Warehouse Project

A full data warehouse built on the Olist Brazilian e-commerce dataset, using SQL Server and a Medallion (Bronze → Silver → Gold) architecture, with Tableau as the reporting layer on top.

This isn't a toy dataset cleaned up for a tutorial. Olist's real data is messy in the way real e-commerce data actually is — customer reviews with commas and line breaks inside the text, duplicate zip codes mapping to multiple lat/lng points, orders that don't cleanly map one-to-one with anything. A good chunk of this project was spent dealing with exactly that.

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

*(Note: consolidate the `test`/`tests` folder duplication before publishing — keep one.)*

## Dataset

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — 99,441 customers, 112,650 order line items, 99,224 reviews, 32,951 products, 3,095 sellers, spanning 2016–2018.

## Running it

1. Restore the Olist CSVs into a SQL Server instance (paths are parameterized at the top of each ingestion script — update before running).
2. Run the Bronze scripts to load raw data.
3. Run `silver.ecommerce_load_bronze` to transform Bronze into Silver.
4. Deploy the Gold layer views (`Script/gold_layer_star_schema.sql`).
5. Run the validation scripts in `tests/` to confirm row counts and data quality before connecting anything to Tableau.

## Tableau

Dashboards are in progress: an executive revenue overview, customer RFM/retention analytics, product and seller performance, logistics/delivery, and customer satisfaction — including a delivery-delay-vs-review-score analysis that's the headline finding of this project so far. Published dashboard link goes here once it's live.

## Status

Bronze and Silver are complete and validated. Gold layer views are built and passing duplicate/integrity checks. Tableau dashboards are the current work in progress.

## License

MIT — see `LICENSE`.
