-- Data assumption behind the tip-rate metric: TLC does not capture cash
-- tips. In January 2022, 93 of 495,154 cash trips (0.02%) carry a tip, $380
-- in total, against $5.7M on card trips. So tip rate is computed over card
-- trips only. If more than 0.5% of cash trips start showing tips, the feed
-- changed and the metric definition needs revisiting.
select
    countif(tip_amount > 0) as cash_trips_with_tips,
    count(*) as cash_trips,
    safe_divide(countif(tip_amount > 0), count(*)) as tipped_share
from {{ ref('fct_taxi_trips') }}
where payment_type_id = 2
having safe_divide(countif(tip_amount > 0), count(*)) > 0.005
