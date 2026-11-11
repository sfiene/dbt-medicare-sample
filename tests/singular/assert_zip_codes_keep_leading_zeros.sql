-- Trap: 2015 outpatient stores zip as INT64 and 2013 inpatient stores it as
-- a float string ('99519.0'). Either way New England and New Jersey zips
-- lose their leading 0 and stop matching any zip-level reference data.
-- Every hospital in these states has a zip starting with 0.
with zips as (
    select 'inpatient' as source, service_year, provider_state, provider_zip5
    from {{ ref('stg_cms__inpatient_charges') }}
    union all
    select 'outpatient', service_year, provider_state, provider_zip5
    from {{ ref('stg_cms__outpatient_charges') }}
)

select source, service_year, provider_state, provider_zip5, count(*) as rows_affected
from zips
where provider_state in ('CT', 'MA', 'ME', 'NH', 'NJ', 'RI', 'VT')
  and not starts_with(provider_zip5, '0')
group by 1, 2, 3, 4
