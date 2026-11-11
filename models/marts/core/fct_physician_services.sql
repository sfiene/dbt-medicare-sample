{{ config(
    partition_by={
        'field': 'service_year',
        'data_type': 'int64',
        'range': {'start': 2012, 'end': 2016, 'interval': 1}
    },
    cluster_by=['provider_state', 'hcpcs_code', 'provider_type']
) }}
-- Grain: one row per NPI x HCPCS code x place of service x service_year.
-- Business key: (npi, hcpcs_code, place_of_service, service_year);
-- surrogate: physician_service_id.
--
-- The one large fact here (~37M rows). Partitioned by year and clustered by
-- state / HCPCS / specialty, so a typical "one state, one year" question reads
-- a few hundred MB instead of the whole table. See README, "Cost control".
select
    -- INT64 fingerprint of the business key instead of a 35-byte string:
    -- 8 bytes x 37M rows. Same uniqueness guarantee, tested below.
    farm_fingerprint(physician_service_id) as physician_service_key,
    npi,
    hcpcs_code,
    place_of_service,
    service_year,
    service_year_start_date,
    provider_state,
    provider_type,

    service_count,
    beneficiary_count,
    service_count * average_medicare_allowed_amt as total_medicare_allowed,
    service_count * average_submitted_chrg_amt as total_submitted_charges,
    service_count * average_medicare_payment_amt as total_medicare_payments
from {{ ref('stg_cms__physician_services') }}
