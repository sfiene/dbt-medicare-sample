{{ config(materialized='ephemeral') }}
-- Grain: one row per trip (no source id; see trip_key).
--
-- Ephemeral, not a view: a view over an unpartitioned 7.5 GB table would
-- re-scan it for every test and every downstream model. Inlined, the source
-- is read once per build, by the incremental fact.
select
    -- The source has no trip id, and the "obvious" natural key (vendor,
    -- pickup, dropoff, zones) collides ~11k times a month. There are no
    -- exact-duplicate rows, so a fingerprint of the whole row is unique.
    farm_fingerprint(to_json_string(t)) as trip_key,
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    date(pickup_datetime) as pickup_date,
    pickup_location_id as pickup_zone_id,
    dropoff_location_id as dropoff_zone_id,
    -- NULL for ~3.4% of trips (the payment_type 0 feed). Kept NULL: an
    -- unrecorded passenger count is not a trip with zero passengers.
    passenger_count,
    trip_distance,
    -- Stored as float strings ('1.0', '99.0'). 99 means unknown.
    safe_cast(safe_cast(rate_code as float64) as int64) as rate_code_id,
    store_and_fwd_flag = 'Y' as is_store_and_forward,
    safe_cast(payment_type as int64) as payment_type_id,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    imp_surcharge,
    airport_fee,
    total_amount
from {{ source('new_york_taxi_trips', 'tlc_yellow_trips_2022') }} as t
-- The 2022 file holds pickups dated 2001-2023. The load window drops them.
where pickup_datetime >= timestamp('{{ var("taxi_start_date") }}')
  and pickup_datetime < timestamp('{{ var("taxi_end_date") }}')
