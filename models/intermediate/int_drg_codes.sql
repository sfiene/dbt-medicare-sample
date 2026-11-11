-- Grain: one row per MS-DRG code.
--
-- Traps handled here:
--   * The same code carries different text in different years (CMS rewords
--     descriptions, e.g. '96+ HOURS' vs '>96 HOURS'). Grouping by the full
--     drg_definition string would split one DRG into two. Key on the 3-digit
--     code and keep the latest description.
--   * 2011-2013 files cover only the top 100 DRGs; 2014-2015 cover ~560.
--     A naive year-over-year total jumps ~30% in 2014 from scope alone.
--     is_in_all_years marks the DRGs that are safe for trend analysis.
{% set n_years = var('inpatient_years') | length %}

with by_code_year as (
    select
        drg_code,
        service_year,
        any_value(drg_description_as_reported) as drg_description
    from {{ ref('stg_cms__inpatient_charges') }}
    group by drg_code, service_year
)

select
    drg_code,
    array_agg(drg_description order by service_year desc limit 1)[offset(0)] as drg_description,
    count(distinct drg_description) as description_variant_count,
    min(service_year) as first_service_year,
    max(service_year) as last_service_year,
    count(distinct service_year) as service_year_count,
    count(distinct service_year) = {{ n_years }} as is_in_all_years
from by_code_year
group by drg_code
