-- Grain: one row per hospital (CCN). Current snapshot, not historized.
select
    {{ clean_ccn('provider_id') }} as provider_id,
    trim(hospital_name) as hospital_name,
    trim(address) as street_address,
    trim(city) as city,
    upper(trim(state)) as state,
    {{ clean_zip5('zip_code') }} as zip5,
    trim(county_name) as county_name,
    trim(hospital_type) as hospital_type,
    trim(hospital_ownership) as hospital_ownership,
    emergency_services as has_emergency_services,
    meets_criteria_for_promoting_interoperability_of_ehrs as meets_ehr_interoperability_criteria,

    -- 'Not Available' -> NULL, never 0. See macros/not_available_to_null.sql.
    {{ not_available_to_int('hospital_overall_rating') }} as overall_star_rating,
    nullif(trim(hospital_overall_rating_footnote), '') as overall_star_rating_footnote,
    {{ not_available_to_int('mortality_measures_better_count') }} as mortality_measures_better_count,
    {{ not_available_to_int('mortality_measures_worse_count') }} as mortality_measures_worse_count,
    {{ not_available_to_int('readmission_measures_better_count') }} as readmission_measures_better_count,
    {{ not_available_to_int('readmission_measures_worse_count') }} as readmission_measures_worse_count,
    {{ not_available_to_int('safety_measures_better_count') }} as safety_measures_better_count,
    {{ not_available_to_int('safety_measures_worse_count') }} as safety_measures_worse_count
from {{ source('cms_medicare', 'hospital_general_info') }}
