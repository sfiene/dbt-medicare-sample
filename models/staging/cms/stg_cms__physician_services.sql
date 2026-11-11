-- Grain: one row per NPI x HCPCS code x place of service (F/O) x service year.
-- The large table in this project (about 37M rows, ~9.6 GB across four years).
-- Only the columns common to every year are selected: 2014+ dropped the
-- stdev_* columns and added average_medicare_standard_amt.
with unioned as (
    {% for yr in var('physician_years') %}
    select
        {{ yr }} as service_year,
        npi,
        nppes_provider_last_org_name,
        nppes_provider_first_name,
        nppes_credentials,
        nppes_provider_gender,
        nppes_entity_code,
        nppes_provider_city,
        nppes_provider_zip,
        nppes_provider_state,
        nppes_provider_country,
        provider_type,
        medicare_participation_indicator,
        place_of_service,
        hcpcs_code,
        hcpcs_description,
        hcpcs_drug_indicator,
        line_srvc_cnt,
        bene_unique_cnt,
        bene_day_srvc_cnt,
        average_medicare_allowed_amt,
        average_submitted_chrg_amt,
        average_medicare_payment_amt
    from {{ source('cms_medicare', 'physicians_and_other_supplier_' ~ yr) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select
    concat(npi, '-', hcpcs_code, '-', place_of_service, '-', cast(service_year as string)) as physician_service_id,
    npi,
    hcpcs_code,
    place_of_service,
    service_year,
    date(service_year, 1, 1) as service_year_start_date,

    trim(nppes_provider_last_org_name) as provider_last_or_org_name,
    nullif(trim(nppes_provider_first_name), '') as provider_first_name,
    nullif(trim(nppes_credentials), '') as provider_credentials,
    -- Blank for organizations (entity code 'O'). NULL, not '' or 'U'.
    nullif(trim(nppes_provider_gender), '') as provider_gender,
    nppes_entity_code as entity_code,
    trim(nppes_provider_city) as provider_city,
    {{ clean_zip5('nppes_provider_zip') }} as provider_zip5,
    upper(trim(nppes_provider_state)) as provider_state,
    nppes_provider_country as provider_country,
    trim(provider_type) as provider_type,
    medicare_participation_indicator = 'Y' as is_medicare_participating,
    trim(hcpcs_description) as hcpcs_description_as_reported,
    hcpcs_drug_indicator = 'Y' as is_drug_service,

    -- FLOAT, not INT: drug HCPCS codes bill fractional units.
    line_srvc_cnt as service_count,
    -- Distinct beneficiaries for THIS npi x hcpcs x place row. Not additive
    -- across rows: one patient can appear under many HCPCS codes.
    bene_unique_cnt as beneficiary_count,
    bene_day_srvc_cnt as beneficiary_day_service_count,
    average_medicare_allowed_amt,
    average_submitted_chrg_amt,
    average_medicare_payment_amt
from unioned
