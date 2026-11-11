-- thelook's generator writes orders a few days ahead of the clock. Left in,
-- "revenue today" includes sales that have not happened. Staging flags them;
-- the marts must not contain any.
select order_id, order_created_at
from {{ ref('fct_orders') }}
where order_created_at > current_timestamp()
