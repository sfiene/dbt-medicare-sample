-- Grain: one row per HCPCS code.
select * from {{ ref('int_hcpcs_codes') }}
