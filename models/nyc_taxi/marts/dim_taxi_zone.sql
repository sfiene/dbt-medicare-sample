-- Grain: one row per TLC zone id (265 rows).
--
-- taxi_zone_geom is not one row per zone: it has 263 rows but only 260
-- distinct ids. Zone 56 appears twice and zone 103 three times, because the
-- polygons for 57, 104 and 105 were filed under those ids. Joining trips to
-- it raw fans out every zone-56 and zone-103 trip. Here the polygons are
-- merged per id, and the seed adds the ids trips use that have no row.
with geom as (
    select
        zone_id,
        any_value(zone_name) as zone_name,
        any_value(borough) as borough,
        st_union_agg(zone_geom) as zone_geom,
        count(*) as source_polygon_rows
    from {{ source('new_york_taxi_trips', 'taxi_zone_geom') }}
    group by zone_id
)

select
    zone_id,
    zone_name,
    borough,
    zone_geom,
    true as has_geometry,
    source_polygon_rows
from geom

union all

select
    zone_id,
    zone_name,
    borough,
    cast(null as geography) as zone_geom,
    false as has_geometry,
    0 as source_polygon_rows
from {{ ref('taxi_zone_supplement') }}
where zone_id not in (select zone_id from geom)
