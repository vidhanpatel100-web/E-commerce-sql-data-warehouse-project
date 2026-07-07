# Datasets

Source data used in this project: the Olist Brazilian E-Commerce Public Dataset.

## Source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — real, anonymized commercial data from Olist, Brazil's largest department store marketplace, covering orders placed between 2016 and 2018.

## License / Attribution

This repository's own code (SQL scripts, documentation) is MIT-licensed — see the root `LICENSE` file. The dataset itself is licensed separately by its owner on Kaggle (listed as CC BY-NC-SA 4.0 — non-commercial, share-alike as of this writing; verify current terms on the Kaggle page directly, since dataset licenses can be updated independently of this repo). This project uses the data for educational/portfolio purposes only.

## Files

| File | Rows | Description |
|---|---|---|
| `olist_customers_dataset.csv` | 99,441 | Customer ID, unique person ID, and location |
| `olist_geolocation_dataset.csv` | 1,000,163 | Brazilian zip code prefix to lat/lng mapping |
| `olist_orders_dataset.csv` | 99,441 | Core order record — status and timestamps |
| `olist_order_items_dataset.csv` | 112,650 | Line items per order — price, freight, seller |
| `olist_order_payments_dataset.csv` | ~103,886 | Payment type, installments, value per order |
| `olist_order_reviews_dataset.csv` | 99,224 | Customer satisfaction reviews |
| `olist_products_dataset.csv` | 32,951 | Product catalog — category, weight, dimensions |
| `olist_sellers_dataset.csv` | 3,095 | Seller ID and location |
| `product_category_name_translation.csv` | 71 | Portuguese to English category name mapping |

#
