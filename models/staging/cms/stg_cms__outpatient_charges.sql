-- Grain: one row per hospital (CCN) x APC x service year.
with unioned as (
    {% for yr in var('outpatient_years') %}
    select
        {{ yr }} as service_year,
        provider_id,
        provider_name,
        provider_street_address,
        provider_city,
        provider_state,
        -- INT64 in 2015, STRING in the other years. Cast before the union.
        cast(provider_zipcode as string) as provider_zipcode,
        apc,
        hospital_referral_region,
        outpatient_services,
        average_estimated_submitted_charges,
        average_total_payments
    from {{ source('cms_medicare', 'outpatient_charges_' ~ yr) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

renamed as (
    select
        {{ clean_ccn('provider_id') }} as provider_id,
        regexp_extract(apc, r'^(\d+) - ') as apc_code,
        service_year,
        date(service_year, 1, 1) as service_year_start_date,

        trim(provider_name) as provider_name,
        trim(provider_street_address) as provider_street_address,
        trim(provider_city) as provider_city,
        upper(trim(provider_state)) as provider_state,
        {{ clean_zip5('provider_zipcode') }} as provider_zip5,
        trim(hospital_referral_region) as hospital_referral_region,
        trim(regexp_extract(apc, r'^\d+ - (.*)$')) as apc_description_as_reported,

        outpatient_services,
        average_estimated_submitted_charges,
        average_total_payments
    from unioned
)

select
    concat(provider_id, '-', apc_code, '-', cast(service_year as string)) as outpatient_charge_id,
    *
from renamed
