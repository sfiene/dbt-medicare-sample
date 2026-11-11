{{ config(
    partition_by={
        'field': 'service_year',
        'data_type': 'int64',
        'range': {'start': 2011, 'end': 2016, 'interval': 1}
    },
    cluster_by=['provider_state', 'drg_code']
) }}
-- Grain: one row per hospital (provider_id) x MS-DRG (drg_code) x service_year.
-- Business key: (provider_id, drg_code, service_year); surrogate: inpatient_charge_id.
--
-- CMS publishes AVERAGES per row. Averages cannot be summed or re-averaged
-- across hospitals: a 12-discharge hospital would weigh the same as a
-- 900-discharge one. So this fact stores discharge-weighted TOTALS, which are
-- additive, and every ratio metric is computed as sum / sum in the semantic layer.
select
    inpatient_charge_id,
    provider_id,
    drg_code,
    service_year,
    service_year_start_date,
    provider_state,
    hospital_referral_region,
    drg_description_as_reported,

    total_discharges,
    total_discharges * average_covered_charges as total_covered_charges,
    total_discharges * average_total_payments as total_payments,
    total_discharges * average_medicare_payments as total_medicare_payments,

    -- Kept for row-level reading only. Do not aggregate these.
    average_covered_charges,
    average_total_payments,
    average_medicare_payments
from {{ ref('stg_cms__inpatient_charges') }}
