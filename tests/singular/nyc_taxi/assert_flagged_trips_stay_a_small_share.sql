-- High-invalid guard. Bad rows are flagged, not dropped. 1.85% of
-- January 2022 trips fail a validity check (zero or impossible distance,
-- impossible speed, refunds, broken timestamps). Past 10%, an upstream feed changed and
-- the rollup is silently losing real trips.
select
    countif(not is_valid_trip) as invalid_trips,
    count(*) as all_trips,
    safe_divide(countif(not is_valid_trip), count(*)) as invalid_share
from {{ ref('fct_taxi_trips') }}
having safe_divide(countif(not is_valid_trip), count(*)) > 0.10
