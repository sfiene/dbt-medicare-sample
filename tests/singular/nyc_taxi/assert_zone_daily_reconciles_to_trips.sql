-- The daily rollup must account for every valid trip and every dollar in
-- the trip fact. Catches a filter or join drift between the two tables.
with daily as (
    select sum(trips) as trips, sum(total_amount) as total_amount
    from {{ ref('fct_taxi_zone_daily') }}
),

trips as (
    select count(*) as trips, sum(total_amount) as total_amount
    from {{ ref('fct_taxi_trips') }}
    where is_valid_trip
)

select r.*, t.trips as fact_trips, t.total_amount as fact_total_amount
from daily as r cross join trips as t
where r.trips != t.trips
   or abs(r.total_amount - t.total_amount) > 0.01
