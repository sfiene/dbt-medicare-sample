# E-commerce module: getting the order grain right

An add-on module to the [Medicare sample](../../README.md). It builds tested
order and order-item marts, plus a semantic layer, on Google's
`bigquery-public-data.thelook_ecommerce`, a synthetic clothing store that is
regenerated every day.

It shows one thing above all: **revenue that adds up the same way at every
grain.** Most broken e-commerce dashboards I have seen fail here.

## The trap

An order has many items. `orders` carries an order-level count
(`num_of_item`), and `order_items` carries the prices. Join them and sum the
order-level count, and every order is counted once per item:

```sql
-- Looks reasonable. Is wrong.
select sum(o.num_of_item)
from orders o
join order_items i using (order_id)
```

| | Items |
|---|---|
| Correct (count the items) | 181,049 |
| Sum `num_of_item` after the join | 343,623 (**1.9x**) |

The same thing happens to any order-level column: shipping cost, discounts,
order counts. It rarely errors. It just inflates numbers.

## How the module avoids it

```
thelook_ecommerce (4 tables)
  -> staging      views, 1:1 with source, renamed and typed, PII dropped
  -> fct_order_items   grain: one row per item       (revenue lives here)
  -> fct_orders        grain: one row per order      (rolled UP from items)
  -> dim_products, dim_customers
  -> semantic layer    order-grain and item-grain measures kept apart
```

- **Revenue is defined once, at the item grain.** `fct_orders` sums it up from
  `fct_order_items`. Nothing ever joins orders down to items and sums.
- **Order and item measures live in separate semantic models.** Average order
  value is order-grain net revenue / order count. Return rate is returned
  items / items. A metric can't accidentally mix grains.
- **A test proves the grains agree.** Revenue, item counts and order counts
  must match between the two facts, to the cent.

| Model | Grain | Business key |
|---|---|---|
| `stg_thelook__orders` | order | order_id |
| `stg_thelook__order_items` | order item | order_item_id |
| `stg_thelook__products` | product | product_id |
| `stg_thelook__customers` | customer | customer_id |
| `fct_order_items` | order item | order_item_id |
| `fct_orders` | order | order_id |
| `dim_products` | product | product_id |
| `dim_customers` | customer | customer_id |

## Other traps found while profiling

| Trap | What it does if missed | Fix | Test |
|---|---|---|---|
| The generator writes rows up to 3 days in the future (1,399 items when profiled) | "Revenue today" includes sales that have not happened | Flagged in staging, dropped at the **order** level so an order never loses some of its items | `assert_no_future_dated_orders_in_marts` |
| Item `created_at` is not the order time (differs on 181,047 of 181,049 items), and 19% of items "ship" before their own `created_at` | Negative fulfillment times | Every item is anchored to its order's timestamp | `expression_is_true: days_to_ship >= 0` |
| `num_of_item` could drift from the real item count | Silent mismatch between order and item views | Kept as `reported_item_count` and reconciled | `expression_is_true: item_count = reported_item_count` |
| Unshipped orders | Filling `days_to_ship` with 0 makes fulfillment look instant | NULL until shipped; the average divides by shipped orders only | `average_days_to_ship` metric definition |
| Returned and cancelled items | Counted as revenue | `net_revenue` is 0 for them: a real zero, not missing | `not_null` on `net_revenue` |
| Name, email and street address in `users` | Copied into every downstream table | Dropped in staging; never leave it | not exposed anywhere downstream |

Because the data changes every day, the tests check relationships and
invariants, never fixed row counts. Source freshness is a real check here
(`warn_after: 2 days`, `error_after: 7 days`).

The tables are about 20 MB, so they are deliberately **not partitioned**.
Partitions that small cost more in metadata than they save. See the
[NYC taxi module](../nyc_taxi/README.md) for the opposite case.

## Semantic layer

Defined in [`_ecommerce__semantic.yml`](_ecommerce__semantic.yml): four
semantic models (`orders`, `order_items`, `customers`, `products`) and 15
metrics, including:

| Metric | Type | Definition |
|---|---|---|
| `average_order_value` | ratio | net revenue / orders, both order grain |
| `items_per_order` | ratio | items / orders |
| `average_days_to_ship` | ratio | days to ship / shipped orders |
| `item_return_rate` | ratio | returned items / items sold |
| `gross_margin_rate` | ratio | gross margin / gross revenue, item grain |

Results from the 2026-11-11 build. thelook regenerates daily, so your numbers
will differ slightly:

```
$ mf query --metrics orders,ecommerce_net_revenue,average_order_value,average_days_to_ship,item_return_rate --group-by metric_time__year
metric_time__year   orders  ecommerce_net_revenue  average_order_value  average_days_to_ship  item_return_rate
2023-01-01           13251                853,883                64.44                  1.49             0.100
2024-01-01           19153              1,222,705                63.84                  1.48             0.100
2025-01-01           27586              1,791,230                64.93                  1.47             0.100
2026-01-01           45672              2,940,106                64.37                  1.49             0.099
```

```
$ mf query --metrics items_sold,item_return_rate,gross_margin_rate --group-by order_item__category --order -items_sold --limit 6
order_item__category            items_sold  item_return_rate  gross_margin_rate
Intimates                            13536             0.100              0.469
Jeans                                12681             0.098              0.465
Tops & Tees                          11935             0.097              0.440
Fashion Hoodies & Sweatshirts        11705             0.093              0.481
Sleep & Lounge                       11260             0.099              0.517
Shorts                               11216             0.098              0.499
```

```
$ mf query --metrics orders,average_order_value --group-by customer__traffic_source --order -orders
customer__traffic_source  orders  average_order_value
search                     87202                64.70
organic                    18770                64.01
facebook                    7521                66.13
email                       6320                62.25
display                     4964                62.77
```

The last one joins order-grain metrics to a customer attribute through the
`customer` entity, with no SQL written for it.

## Run just this module

From the project root, with the environment set up as in the
[main README](../../README.md#how-to-run-it):

```bash
dbt build --select path:models/ecommerce path:tests/singular/ecommerce
```

```bash
dbt source freshness --select source:thelook_ecommerce
```

A full build of the module processes under 100 MB.

## Files

- [`staging/`](staging/): sources (with freshness) and the four staging views
- [`marts/`](marts/): facts and dimensions
- [`_ecommerce__models.yml`](_ecommerce__models.yml): descriptions and tests
- [`_ecommerce__semantic.yml`](_ecommerce__semantic.yml): semantic models and metrics
- [`../../tests/singular/ecommerce/`](../../tests/singular/ecommerce/): the fan-out and future-date tests
