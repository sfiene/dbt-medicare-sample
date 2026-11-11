-- The order vs order-item grain trap.
-- Revenue summed at the order grain must equal revenue summed at the item
-- grain. The classic bug: join orders to items, then sum an order-level
-- column. On this data that turns 181k items into ~344k (1.9x).
-- This fails if fct_orders ever picks up a join that repeats rows.
with order_grain as (
    select sum(gross_revenue) as revenue, sum(item_count) as items, count(*) as orders
    from {{ ref('fct_orders') }}
),

item_grain as (
    select sum(gross_revenue) as revenue, count(*) as items, count(distinct order_id) as orders
    from {{ ref('fct_order_items') }}
)

select o.*, i.revenue as item_revenue, i.items as item_rows, i.orders as item_orders
from order_grain as o cross join item_grain as i
where abs(o.revenue - i.revenue) > 0.01
   or o.items != i.items
   or o.orders != i.orders
