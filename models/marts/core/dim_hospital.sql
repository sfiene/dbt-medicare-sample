-- Grain: one row per hospital CCN (provider_id).
select * from {{ ref('int_hospitals__resolved') }}
