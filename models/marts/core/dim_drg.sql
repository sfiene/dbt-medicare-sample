-- Grain: one row per MS-DRG code.
select * from {{ ref('int_drg_codes') }}
