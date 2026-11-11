-- NULL vs 0 policy. CMS writes 'Not Available' for unrated hospitals (~38%).
-- Those must land as NULL: a 0 would pull the national average rating down
-- by more than a full star and rank unrated hospitals below 1-star ones.
-- Fails if any rating is 0, or if the number of NULL ratings does not equal
-- the number of 'Not Available' strings in the source.
with source_na as (
    select countif(trim(hospital_overall_rating) = 'Not Available') as n
    from {{ source('cms_medicare', 'hospital_general_info') }}
),

dim_nulls as (
    select
        countif(overall_star_rating is null) as null_ratings,
        countif(overall_star_rating = 0) as zero_ratings
    from {{ ref('dim_hospital') }}
    where has_general_info
)

select source_na.n as source_not_available, dim_nulls.*
from source_na cross join dim_nulls
where dim_nulls.zero_ratings > 0
   or dim_nulls.null_ratings != source_na.n
