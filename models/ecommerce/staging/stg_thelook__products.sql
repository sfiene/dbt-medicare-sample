-- Grain: one row per product.
select
    id as product_id,
    trim(name) as product_name,
    trim(brand) as brand,
    trim(category) as category,
    trim(department) as department,
    cost as unit_cost,
    retail_price,
    distribution_center_id
from {{ source('thelook_ecommerce', 'products') }}
