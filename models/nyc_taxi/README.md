# NYC taxi module: partitioning and cost on a table that has none

An add-on module to the [Medicare sample](../../README.md). It builds a
partitioned, incrementally loaded trip fact, a daily rollup and a semantic
layer on `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`.

The source is the interesting part: **36.3M rows, 7.5 GB, and not partitioned
or clustered.** Every query against it reads every byte of the columns it
touches, whatever the `WHERE` clause says. This module is about making sure
that cost is paid once, and never by a dashboard.

## The result

The same question, "JFK pickups on 2022-01-15", asked at each layer. Every
row returns the same answer (3,205 trips, $145,993.48), except the rollup,
which counts valid trips only:

| Where the query runs | Bytes processed |
|---|---|
| Raw source | 1,045.3 MB |
| `fct_taxi_trips`, whole month, no filter | 39.4 MB |
| `fct_taxi_trips`, that day only (partition pruning) | 2.1 MB |
| `fct_taxi_trips`, that day and zone | **2.6 MB**, 400x less than raw |
| `fct_taxi_zone_daily`, that day and zone | 0.2 MB |

BigQuery bills at least 10 MB per query, so the last three cost the same. On
one month of data, clustering adds nothing on top of the daily partition. It
starts paying off once the load window covers a year.

## Design

```
tlc_yellow_trips_2022 (unpartitioned, 7.5 GB)
  -> stg_tlc__yellow_trips   ephemeral: inlined, so the source is read once per build
  -> fct_taxi_trips          one row per trip; partitioned by day, clustered by
                             pickup zone + payment type; incremental insert_overwrite
  -> fct_taxi_zone_daily     one row per day x pickup zone; valid trips only (~7k rows/month)
  -> dim_taxi_zone           one row per TLC zone (265)
  -> semantic layer          reads the rollup, never the trip fact
```

- **Staging is ephemeral, not a view.** A view over an unpartitioned 7.5 GB
  table would be re-scanned by every test and every downstream model.
- **No tests on staging**, for the same reason. They run on the partitioned
  fact, a 0.6 GB table, instead of the 7.5 GB source.
- **The fact is partitioned by day and clustered** by pickup zone and payment
  type.
- **Incremental with `insert_overwrite`.** Each run rebuilds only the last
  `taxi_lookback_days` (3) days of partitions, to pick up late-arriving trips,
  through a MERGE limited to those partitions.
- **Bad rows are flagged, not deleted**, so they can be counted and explained.
  The rollup uses only `is_valid_trip`.
- **The load window is a variable.** One month by default; widen it with
  `--vars '{taxi_end_date: "2023-01-01"}'`.

| Model | Grain | Business key |
|---|---|---|
| `stg_tlc__yellow_trips` (ephemeral) | trip | trip_key |
| `fct_taxi_trips` | trip | trip_key |
| `fct_taxi_zone_daily` | pickup date x pickup zone | pickup_date, pickup_zone_id |
| `dim_taxi_zone` | TLC zone | zone_id |
| seed `taxi_zone_supplement` | zone id missing from the geometry table | zone_id |

## The incremental run, verified

After a full build of January 2022, a plain `dbt build --select fct_taxi_trips`
on a billed project:

| Check | Result |
|---|---|
| Partitions rewritten | Jan 28-31 only; the other 27 untouched |
| MERGE row counts | 287,389 deleted, 287,389 inserted: exactly those four days |
| Table rows before and after | 2,463,900 and 2,463,900 |
| Bytes, MERGE into the target | 141 MB |
| Bytes, reading the source | 7.5 GB |

The last row is the lesson. Incremental loading makes the writes cheap, but
the source is unpartitioned, so each run still pays for a full read of the
columns it touches. On a client project the real fix is upstream: land the raw
data partitioned, and this same model reads a few days of it instead of a
year.

## Traps found while profiling

| Trap | What it does if missed | Fix | Test |
|---|---|---|---|
| The 2022 file holds pickups dated 2001-2023 | Stray years in every time series | Load window on `pickup_datetime` | `expression_is_true` on `pickup_date` |
| No trip id, and the obvious key (vendor, pickup, dropoff, zones) collides 11,369 times in January | `unique` on that key fails, or dedup deletes real trips | `FARM_FINGERPRINT` of the whole row; there are no exact duplicates | `unique` on `trip_key` |
| `taxi_zone_geom` has 263 rows but only 260 ids: 56 appears twice and 103 three times | Joining trips to zones double- and triple-counts those zones | Polygons merged per id with `ST_UNION_AGG` | `unique` on `dim_taxi_zone.zone_id` |
| Zone ids 57, 104, 105, 264 and 265 have no row at all | 29,795 January trips (1.2%) match no zone | Seed `taxi_zone_supplement` from the TLC zone lookup | `relationships` from both zone columns |
| 134 trips claim over 100 miles (max 306,159) and hold 42% of all recorded miles | Average speed in the Bronx: 206 mph | `has_plausible_distance` (<= 100 mi), `has_plausible_speed` (<= 80 mph) | Bronx reads 15.0 mph after; `assert_flagged_trips_stay_a_small_share` |
| TLC does not record cash tips (93 of 495,154 cash trips have one) | Tip rate over all fares: 18.6% | `taxi_card_tip_rate` = card tips / card fares: 24.0% | `assert_cash_trips_record_no_tips` (fails past 0.5%) |
| `passenger_count` is NULL on 3.4% of trips (the payment type 0 feed) | Average over all trips: 1.353 | Divide by trips with a recorded count: 1.392 | `null_proportion_at_most 0.05` |
| Refunds and voids (228k negative totals in 2022), zero distance, dropoff before pickup | Negative or inflated revenue | Flagged; excluded from the rollup | `assert_zone_daily_reconciles_to_trips` |
| `rate_code` stored as float strings (`'99.0'`); payment type 0 is undocumented | Join and filter misses | Parsed to INT64; 0 labelled "not recorded" | `accepted_values` |

Overall, 1.85% of January trips fail at least one validity check. The test
fails if that passes 10%, which would mean an upstream feed changed.

## Semantic layer

Defined in [`_nyc_taxi__semantic.yml`](_nyc_taxi__semantic.yml): two semantic
models (`taxi_zone_daily`, `taxi_zones`) and 12 metrics. Every average carries
its own denominator:

| Metric | Type | Definition |
|---|---|---|
| `taxi_fare_per_trip` | ratio | fares / trips |
| `taxi_avg_passengers` | ratio | passengers / trips **with a recorded count** |
| `taxi_card_tip_rate` | ratio | card tips / **card** fares |
| `taxi_avg_speed_mph` | derived | total miles / total minutes x 60 (distance-weighted) |

```
$ mf query --metrics taxi_trips,taxi_fare_per_trip,taxi_card_tip_rate --group-by pickup_zone__zone_name --order -taxi_trips --limit 5
pickup_zone__zone_name         taxi_trips  taxi_fare_per_trip  taxi_card_tip_rate
Upper East Side South              120549                8.96               0.263
Upper East Side North              119786                9.59               0.256
JFK Airport                        100457               45.53               0.197
Midtown Center                      87294               10.38               0.257
Penn Station/Madison Sq West        79671               10.99               0.251
```

```
$ mf query --metrics taxi_trips,taxi_fare_per_trip,taxi_avg_passengers,taxi_card_tip_rate,taxi_avg_speed_mph --group-by pickup_zone__borough --order -taxi_trips
pickup_zone__borough  taxi_trips  taxi_fare_per_trip  taxi_avg_passengers  taxi_card_tip_rate  taxi_avg_speed_mph
Manhattan                2198637               10.67                 1.39               0.252               10.86
Queens                    180615               38.01                 1.44               0.206               24.83
Unknown                    21236               18.31                 1.36               0.226               18.30
Brooklyn                   11812               21.53                 1.29               0.108               13.51
Outside of NYC              3076               45.34                 1.38               0.162               10.50
Bronx                       2866               27.04                 1.17               0.022               14.95
Staten Island                100               68.85                 1.01               0.005               20.67
EWR                           51               69.70                 1.59               0.178               18.50
```

Queens' speed and fare are JFK and LaGuardia runs. The low Bronx and Brooklyn
tip rates are not a cash artifact: the metric already covers card trips only,
and their cash share (24% and 19%) is close to Manhattan's (20%). Card trips
from those pickups simply record far fewer tips. I would check street-hail vs
dispatched trips before explaining why, rather than guess.

## Running it in the free BigQuery sandbox

The module works without billing, with one switch: `export DBT_BQ_SANDBOX=true`.
The sandbox has two rules that break the normal design:

1. **DATE partitions older than 60 days are deleted on write**, with no
   table-level override. 2022 data vanishes the moment it lands. In sandbox
   mode the fact partitions on an INT64 day number (`pickup_unix_day`)
   instead, which the rule does not touch.
2. **No DML**, so `insert_overwrite` cannot run. In sandbox mode the fact
   builds as a plain table.

The switch lives in [`macros/bq_sandbox.sql`](../../macros/bq_sandbox.sql).
If you later link billing, clear the 60-day defaults on the datasets the
sandbox created, then run `dbt build --full-refresh`. Otherwise DATE
partitions keep expiring.

## Run just this module

From the project root, with the environment set up as in the
[main README](../../README.md#how-to-run-it):

```bash
dbt build --select path:models/nyc_taxi path:tests/singular/nyc_taxi path:seeds
```

Expect about 7.5 GB processed, almost all of it the one read of the source.

## Files

- [`staging/`](staging/): sources and the ephemeral staging model
- [`marts/`](marts/): trip fact, daily rollup, zone dimension
- [`_nyc_taxi__models.yml`](_nyc_taxi__models.yml): descriptions and tests
- [`_nyc_taxi__semantic.yml`](_nyc_taxi__semantic.yml): semantic models and metrics
- [`../../seeds/taxi_zone_supplement.csv`](../../seeds/taxi_zone_supplement.csv): zone ids missing from the geometry table
- [`../../tests/singular/nyc_taxi/`](../../tests/singular/nyc_taxi/): reconciliation, tip-assumption and invalid-share tests
