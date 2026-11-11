-- Grain: one row per product.
select * from {{ ref('stg_thelook__products') }}
