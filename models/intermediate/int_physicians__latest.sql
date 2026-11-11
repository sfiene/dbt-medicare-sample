-- Grain: one row per NPI.
-- Physician attributes repeat on every service row and can change by year
-- (moves, new credentials). Keep the most recent year's attributes, plus
-- first/last active year.
with history as (
    select
        npi,
        min(service_year) as first_service_year,
        max(service_year) as last_service_year
    from {{ ref('stg_cms__physician_services') }}
    group by npi
),

latest as (
    select
        npi,
        provider_last_or_org_name,
        provider_first_name,
        provider_credentials,
        provider_gender,
        entity_code,
        provider_city,
        provider_state,
        provider_zip5,
        provider_country,
        provider_type,
        is_medicare_participating
    from {{ ref('stg_cms__physician_services') }}
    qualify row_number() over (
        partition by npi
        order by service_year desc, hcpcs_code, place_of_service
    ) = 1
)

select
    latest.*,
    history.first_service_year,
    history.last_service_year
from latest
inner join history using (npi)
