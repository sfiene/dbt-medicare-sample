-- Grain: one row per customer.
-- Name, email, street address, postal code and exact coordinates are dropped
-- here on purpose. Downstream models never need them, so they never leave
-- staging. Same habit as a real client's customer table.
select
    id as customer_id,
    age,
    gender,
    trim(state) as state,
    trim(country) as country,
    lower(traffic_source) as traffic_source,
    created_at as customer_created_at
from {{ source('thelook_ecommerce', 'users') }}
