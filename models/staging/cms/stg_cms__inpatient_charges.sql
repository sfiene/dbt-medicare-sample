-- Grain: one row per hospital (CCN) x MS-DRG x service year.
-- Unions the yearly files with explicit column lists, because the files are
-- not type-identical across years and `select *` hides that.
with unioned as (
    {% for yr in var('inpatient_years') %}
    select
        {{ yr }} as service_year,
        provider_id,
        provider_name,
        provider_street_address,
        provider_city,
        provider_state,
        cast(provider_zipcode as string) as provider_zipcode,
        drg_definition,
        hospital_referral_region_description,
        total_discharges,
        average_covered_charges,
        average_total_payments,
        average_medicare_payments
    from {{ source('cms_medicare', 'inpatient_charges_' ~ yr) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

renamed as (
    select
        {{ clean_ccn('provider_id') }} as provider_id,
        regexp_extract(drg_definition, r'^(\d{3}) - ') as drg_code,
        service_year,
        date(service_year, 1, 1) as service_year_start_date,

        trim(provider_name) as provider_name,
        trim(provider_street_address) as provider_street_address,
        trim(provider_city) as provider_city,
        upper(trim(provider_state)) as provider_state,
        {{ clean_zip5('provider_zipcode') }} as provider_zip5,
        trim(hospital_referral_region_description) as hospital_referral_region,
        trim(regexp_extract(drg_definition, r'^\d{3} - (.*)$')) as drg_description_as_reported,

        total_discharges,
        average_covered_charges,
        average_total_payments,
        average_medicare_payments
    from unioned
)

select
    concat(provider_id, '-', drg_code, '-', cast(service_year as string)) as inpatient_charge_id,
    *
from renamed
