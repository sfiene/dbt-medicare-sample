-- Grain: one row per order. Business key: order_id.
--
-- Order totals are rolled UP from fct_order_items, never joined DOWN to it.
-- Joining orders to items and summing an order-level column (like
-- num_of_item) repeats that value once per item.
with item_rollup as (
    select
        order_id,
        count(*) as item_count,
        countif(is_returned) as returned_item_count,
        sum(gross_revenue) as gross_revenue,
        sum(net_revenue) as net_revenue,
        sum(item_cost) as item_cost,
        sum(gross_margin) as gross_margin
    from {{ ref('fct_order_items') }}
    group by order_id
),

orders as (
    select * from {{ ref('stg_thelook__orders') }}
    where not is_future_dated
)

select
    orders.order_id,
    orders.customer_id,
    orders.order_status,
    orders.order_created_at,
    orders.order_created_date,
    orders.order_shipped_at,
    orders.order_delivered_at,

    item_rollup.item_count,
    orders.reported_item_count,
    item_rollup.returned_item_count,
    item_rollup.gross_revenue,
    item_rollup.net_revenue,
    item_rollup.item_cost,
    item_rollup.gross_margin,
    -- NULL until shipped. Not 0: an unshipped order did not ship instantly.
    timestamp_diff(orders.order_shipped_at, orders.order_created_at, hour) / 24.0 as days_to_ship,
    timestamp_diff(orders.order_delivered_at, orders.order_created_at, hour) / 24.0 as days_to_deliver
from orders
inner join item_rollup using (order_id)
