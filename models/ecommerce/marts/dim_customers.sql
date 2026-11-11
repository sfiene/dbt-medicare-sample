-- Grain: one row per customer. No PII (see stg_thelook__customers).
select
    *,
    case
        when age < 25 then '18-24'
        when age < 35 then '25-34'
        when age < 50 then '35-49'
        when age < 65 then '50-64'
        else '65+'
    end as age_band
from {{ ref('stg_thelook__customers') }}
