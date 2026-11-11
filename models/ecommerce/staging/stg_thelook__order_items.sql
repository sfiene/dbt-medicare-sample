-- Grain: one row per order item.
select
    id as order_item_id,
    order_id,
    user_id as customer_id,
    product_id,
    lower(status) as item_status,
    -- Item timestamps are offsets the generator applies per item; they do not
    -- equal the order's created_at, and 19% of items "ship" before their own
    -- created_at. Fulfillment durations are measured from the ORDER time.
    created_at as item_created_at,
    shipped_at as item_shipped_at,
    delivered_at as item_delivered_at,
    returned_at as item_returned_at,
    sale_price,
    created_at > current_timestamp() as is_future_dated
from {{ source('thelook_ecommerce', 'order_items') }}
