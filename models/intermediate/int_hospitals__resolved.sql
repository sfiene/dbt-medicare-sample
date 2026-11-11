-- Grain: one row per hospital CCN, across every source that mentions one.
--
-- Two traps handled here:
--   1. The charge files carry hospital attributes on every row, and they drift
--      year to year (about 700 hospitals change name across 2011-2015). Taking
--      attributes from "any" row would make the dimension non-deterministic,
--      so we keep the most recent charge-file row per CCN.
--   2. Not every billing hospital is in hospital_general_info (about 7% of
--      2015 inpatient CCNs are missing), and not every listed hospital bills.
--      A full outer join keeps both, with flags saying where each came from.

with charge_rows as (
    select
        provider_id, service_year, 1 as source_rank,
        provider_name, provider_street_address, provider_city,
        provider_state, provider_zip5, hospital_referral_region
    from {{ ref('stg_cms__inpatient_charges') }}

    union all

    select
        provider_id, service_year, 2 as source_rank,
        provider_name, provider_street_address, provider_city,
        provider_state, provider_zip5, hospital_referral_region
    from {{ ref('stg_cms__outpatient_charges') }}
),

charge_history as (
    select
        provider_id,
        min(service_year) as first_charge_year,
        max(service_year) as last_charge_year,
        count(distinct provider_name) as charge_name_variant_count
    from charge_rows
    group by provider_id
),

latest_charge_row as (
    select *
    from charge_rows
    qualify row_number() over (
        partition by provider_id
        order by service_year desc, source_rank, provider_name
    ) = 1
),

charge_providers as (
    select
        l.provider_id,
        l.provider_name,
        l.provider_street_address,
        l.provider_city,
        l.provider_state,
        l.provider_zip5,
        l.hospital_referral_region,
        h.first_charge_year,
        h.last_charge_year,
        h.charge_name_variant_count
    from latest_charge_row as l
    inner join charge_history as h using (provider_id)
),

general_info as (
    select * from {{ ref('stg_cms__hospital_general_info') }}
)

select
    coalesce(g.provider_id, c.provider_id) as provider_id,
    -- Hospital Compare is the curated current name; fall back to the billing file.
    coalesce(g.hospital_name, c.provider_name) as hospital_name,
    coalesce(g.street_address, c.provider_street_address) as street_address,
    coalesce(g.city, c.provider_city) as city,
    coalesce(g.state, c.provider_state) as state,
    coalesce(g.zip5, c.provider_zip5) as zip5,
    g.county_name,
    c.hospital_referral_region,
    g.hospital_type,
    g.hospital_ownership,
    g.has_emergency_services,
    g.meets_ehr_interoperability_criteria,
    g.overall_star_rating,
    g.overall_star_rating_footnote,
    g.mortality_measures_better_count,
    g.mortality_measures_worse_count,
    g.readmission_measures_better_count,
    g.readmission_measures_worse_count,
    g.safety_measures_better_count,
    g.safety_measures_worse_count,
    c.first_charge_year,
    c.last_charge_year,
    coalesce(c.charge_name_variant_count, 0) as charge_name_variant_count,
    g.provider_id is not null as has_general_info,
    c.provider_id is not null as has_charge_data
from general_info as g
full outer join charge_providers as c
    on g.provider_id = c.provider_id
