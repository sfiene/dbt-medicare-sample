{{ config(
    materialized='table' if is_bq_sandbox() else 'incremental',
    incremental_strategy='insert_overwrite',
    partition_by=daily_partition_config('pickup_date', 'pickup_unix_day', var('taxi_start_date'), var('taxi_end_date')),
    cluster_by=['pickup_zone_id', 'payment_type_id'],
    on_schema_change='fail'
) }}
-- Grain: one row per trip. Business key: trip_key.
--
-- Cost design:
--   * Partitioned by day, clustered by pickup zone and payment type.
--     Downstream reads of one day or one zone touch a sliver of it. On a
--     billed project the partition is pickup_date (DATE); in the free
--     sandbox it is pickup_unix_day (INT64), see macros/bq_sandbox.sql.
--   * Incremental with insert_overwrite: each run replaces only the partitions
--     it recomputes (the last taxi_lookback_days days) instead of the table.
--     No MERGE, so no full scan of the target to match keys.
--   * The sandbox allows no DML, and insert_overwrite needs it, so with
--     DBT_BQ_SANDBOX=true this builds as a plain table instead.
--   * The SOURCE is unpartitioned, so reading it costs the same whatever the
--     filter. That is paid once per build here, and nowhere else.
--
-- Bad rows are flagged, not deleted, so they can be counted and explained.
with trips as (
    select * from {{ ref('stg_tlc__yellow_trips') }}
    {% if is_incremental() %}
    -- _dbt_max_partition is the newest partition already in this table.
    {% if is_bq_sandbox() %}
    where unix_date(pickup_date) >= _dbt_max_partition - {{ var('taxi_lookback_days') }}
    {% else %}
    where pickup_date >= date_sub(_dbt_max_partition, interval {{ var('taxi_lookback_days') }} day)
    {% endif %}
    {% endif %}
),

flagged as (
    select
        *,
        dropoff_datetime > pickup_datetime
            and timestamp_diff(dropoff_datetime, pickup_datetime, minute) <= 24 * 60 as has_valid_duration,
        trip_distance > 0 as has_positive_distance,
        trip_distance <= 100 as has_plausible_distance,
        -- Unknown (NULL) when the trip has no positive duration; treated as not plausible.
        coalesce(
            safe_divide(cast(trip_distance as float64),
                        timestamp_diff(dropoff_datetime, pickup_datetime, second) / 3600.0) <= 80,
            false
        ) as has_plausible_speed,
        total_amount < 0 as is_refund_or_void
    from trips
)

select
    trip_key,
    pickup_date,
    unix_date(pickup_date) as pickup_unix_day,
    pickup_datetime,
    dropoff_datetime,
    pickup_zone_id,
    dropoff_zone_id,
    vendor_id,
    rate_code_id,
    payment_type_id,
    case payment_type_id
        when 1 then 'credit card'
        when 2 then 'cash'
        when 3 then 'no charge'
        when 4 then 'dispute'
        when 5 then 'unknown'
        when 6 then 'voided'
        when 0 then 'not recorded'
    end as payment_type,
    is_store_and_forward,
    passenger_count,
    trip_distance,
    timestamp_diff(dropoff_datetime, pickup_datetime, second) / 60.0 as trip_minutes,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    imp_surcharge,
    airport_fee,
    total_amount,

    has_valid_duration,
    has_positive_distance,
    -- 134 January trips claim over 100 miles (max 306,159) and together hold
    -- 42% of all recorded miles. Ratios of sums do not survive inputs like that.
    has_plausible_distance,
    has_plausible_speed,
    is_refund_or_void,
    has_valid_duration
        and has_positive_distance
        and has_plausible_distance
        and has_plausible_speed
        and not is_refund_or_void as is_valid_trip
from flagged
