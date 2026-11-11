-- Reconciliation. Discharge-weighted Medicare payments per year in the mart
-- must match the same calculation run straight against the raw CMS files,
-- to the cent. Catches dropped rows in the union, a bad join upstream, or
-- someone "fixing" the fact to average the averages.
with source_totals as (
    {% for yr in var('inpatient_years') %}
    select
        {{ yr }} as service_year,
        sum(total_discharges) as discharges,
        sum(total_discharges * average_medicare_payments) as medicare_payments
    from {{ source('cms_medicare', 'inpatient_charges_' ~ yr) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

mart_totals as (
    select
        service_year,
        sum(total_discharges) as discharges,
        sum(total_medicare_payments) as medicare_payments
    from {{ ref('fct_inpatient_charges') }}
    group by service_year
)

select
    coalesce(s.service_year, m.service_year) as service_year,
    s.discharges as source_discharges,
    m.discharges as mart_discharges,
    s.medicare_payments as source_medicare_payments,
    m.medicare_payments as mart_medicare_payments
from source_totals as s
full outer join mart_totals as m using (service_year)
where s.service_year is null
   or m.service_year is null
   or s.discharges != m.discharges
   or abs(s.medicare_payments - m.medicare_payments) > 0.01
