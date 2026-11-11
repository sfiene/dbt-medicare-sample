-- Trap: the charge files drop the CCN's leading zero ('70029' vs '070029').
-- Joined raw, only 73-77% of each year's inpatient hospitals match Hospital
-- Compare, and every hospital in states 01-09 (AL through CT) disappears.
-- Padded, coverage is 88.9% (2011) to 93.4% (2015). It is below 100% and
-- decays with age because Hospital Compare is a current snapshot: hospitals
-- that closed or merged after 2011 are not in it.
--
-- 85% sits between the worst padded year and the best raw year, so this
-- fails on a padding regression without failing on normal closures.
with coverage as (
    select
        f.service_year,
        count(distinct f.provider_id) as hospitals,
        count(distinct if(h.has_general_info, f.provider_id, null)) as matched_hospitals
    from {{ ref('fct_inpatient_charges') }} as f
    left join {{ ref('dim_hospital') }} as h using (provider_id)
    group by f.service_year
)

select *, safe_divide(matched_hospitals, hospitals) as match_ratio
from coverage
where safe_divide(matched_hospitals, hospitals) < 0.85
