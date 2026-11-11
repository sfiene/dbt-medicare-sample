-- Grain: one row per HCPCS code.
-- Moving the description and drug flag here, instead of repeating them on
-- 37M fact rows, cut fct_physician_services from 7 GB to a fraction of that.
-- That is what keeps a full rebuild inside the 10 GB BigQuery sandbox.
select
    hcpcs_code,
    array_agg(hcpcs_description_as_reported order by service_year desc limit 1)[offset(0)] as hcpcs_description,
    logical_or(is_drug_service) as is_drug_service,
    min(service_year) as first_service_year,
    max(service_year) as last_service_year
from {{ ref('stg_cms__physician_services') }}
group by hcpcs_code
