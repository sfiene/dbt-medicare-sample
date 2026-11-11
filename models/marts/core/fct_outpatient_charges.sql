{{ config(
    partition_by={
        'field': 'service_year',
        'data_type': 'int64',
        'range': {'start': 2011, 'end': 2016, 'interval': 1}
    },
    cluster_by=['provider_state', 'apc_code']
) }}
-- Grain: one row per hospital (provider_id) x APC (apc_code) x service_year.
-- Business key: (provider_id, apc_code, service_year); surrogate: outpatient_charge_id.
-- Same averages-to-totals conversion as fct_inpatient_charges.
select
    outpatient_charge_id,
    provider_id,
    apc_code,
    service_year,
    service_year_start_date,
    provider_state,
    hospital_referral_region,
    apc_description_as_reported,

    outpatient_services,
    outpatient_services * average_estimated_submitted_charges as total_submitted_charges,
    outpatient_services * average_total_payments as total_payments,

    average_estimated_submitted_charges,
    average_total_payments
from {{ ref('stg_cms__outpatient_charges') }}
