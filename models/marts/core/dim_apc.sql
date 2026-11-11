-- Grain: one row per APC code.
select * from {{ ref('int_apc_codes') }}
