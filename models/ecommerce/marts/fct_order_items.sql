-- Grain: one row per order item. Business key: order_item_id.
--
-- Not partitioned or clustered, on purpose: the table is ~20 MB. Partitions
-- this small add metadata overhead and save nothing. The taxi module shows
-- the opposite case.
with items as (
    select * from {{ ref('stg_thelook__order_items') }}
),

-- Future-dated rows are dropped at the ORDER level, so an order never loses
-- some of its items and keeps others.
orders as (
    select order_id, order_created_at, order_created_date
    from {{ ref('stg_thelook__orders') }}
    where not is_future_dated
),

products as (
    select product_id, unit_cost, category, department, brand
    from {{ ref('stg_thelook__products') }}
)

select
    items.order_item_id,
    items.order_id,
    items.customer_id,
    items.product_id,
    items.item_status,
    -- Anchor every item to its ORDER date. Item-level created_at is a
    -- generator offset and does not match the order time.
    orders.order_created_at,
    orders.order_created_date,
    products.category,
    products.department,
    products.brand,

    items.sale_price as gross_revenue,
    products.unit_cost as item_cost,
    items.sale_price - products.unit_cost as gross_margin,
    items.item_status = 'returned' as is_returned,
    items.item_status = 'cancelled' as is_cancelled,
    -- 0, not NULL, for returned or cancelled items: the store earned nothing
    -- on them, which is a real zero.
    if(items.item_status in ('returned', 'cancelled'), 0, items.sale_price) as net_revenue
from items
inner join orders using (order_id)
inner join products using (product_id)
