-- Fan-out check. Joining the fact to its dimensions must not change the row
-- count. If dim_drg were keyed on the full drg_definition text (which CMS
-- rewords between years) instead of the 3-digit code, three DRGs would
-- appear twice and this join would double their rows and their dollars.
with fact_rows as (
    select count(*) as n from {{ ref('fct_inpatient_charges') }}
),

joined_rows as (
    select count(*) as n
    from {{ ref('fct_inpatient_charges') }} as f
    inner join {{ ref('dim_hospital') }} as h using (provider_id)
    inner join {{ ref('dim_drg') }} as d using (drg_code)
)

select fact_rows.n as fact_rows, joined_rows.n as joined_rows
from fact_rows cross join joined_rows
where fact_rows.n != joined_rows.n
