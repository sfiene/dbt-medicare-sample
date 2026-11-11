{{ config(cluster_by=['pickup_date', 'pickup_zone_id']) }}
-- Grain: one row per pickup_date x pickup_zone_id. Valid trips only.
-- Business key: (pickup_date, pickup_zone_id).
--
-- The small table dashboards and the semantic layer read. One month of trips
-- (~2.5M rows) becomes ~7k rows here, so it is clustered, not partitioned:
-- partitions this small cost more in metadata than they save.
--
-- Two aggregation traps handled with separate denominators:
--   * Passenger count is NULL for ~3% of trips. Average passengers is
--     passengers / trips WITH a recorded count, not / all trips.
--   * TLC only records tips paid by card; cash tips are absent, not zero.
--     Tip rate is card tips / card fares. Over all trips it would read ~30%
--     low.
select
    pickup_date,
    pickup_zone_id,
    count(*) as trips,
    countif(passenger_count is not null) as trips_with_passenger_count,
    sum(passenger_count) as passengers,
    sum(trip_distance) as trip_miles,
    sum(trip_minutes) as trip_minutes,
    sum(fare_amount) as fare_amount,
    sum(total_amount) as total_amount,
    countif(payment_type_id = 1) as card_trips,
    sum(if(payment_type_id = 1, fare_amount, 0)) as card_fare_amount,
    sum(if(payment_type_id = 1, tip_amount, 0)) as card_tip_amount
from {{ ref('fct_taxi_trips') }}
where is_valid_trip
group by pickup_date, pickup_zone_id
