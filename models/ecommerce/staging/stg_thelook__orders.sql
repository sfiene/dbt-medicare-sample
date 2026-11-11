-- Grain: one row per order.
select
    order_id,
    user_id as customer_id,
    lower(status) as order_status,
    created_at as order_created_at,
    date(created_at) as order_created_date,
    shipped_at as order_shipped_at,
    delivered_at as order_delivered_at,
    returned_at as order_returned_at,
    -- Order-level count. Never sum this after joining to items: it repeats
    -- on every item row and inflates the total about 1.9x.
    num_of_item as reported_item_count,
    -- The generator writes rows a few days into the future.
    created_at > current_timestamp() as is_future_dated
from {{ source('thelook_ecommerce', 'orders') }}
