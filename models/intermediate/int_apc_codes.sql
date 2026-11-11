-- Grain: one row per APC code.
-- Same pattern as int_drg_codes. APC wording drifts more than DRG wording
-- (CMS re-levels APCs, e.g. '0015 - Level II' became '0015 - Level III'), so
-- the fact table also keeps the description as reported that year.
{% set n_years = var('outpatient_years') | length %}

with by_code_year as (
    select
        apc_code,
        service_year,
        any_value(apc_description_as_reported) as apc_description
    from {{ ref('stg_cms__outpatient_charges') }}
    group by apc_code, service_year
)

select
    apc_code,
    array_agg(apc_description order by service_year desc limit 1)[offset(0)] as apc_description,
    count(distinct apc_description) as description_variant_count,
    min(service_year) as first_service_year,
    max(service_year) as last_service_year,
    count(distinct service_year) as service_year_count,
    count(distinct service_year) = {{ n_years }} as is_in_all_years
from by_code_year
group by apc_code
