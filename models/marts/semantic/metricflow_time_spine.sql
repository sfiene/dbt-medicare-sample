-- Daily date spine MetricFlow uses to fill and join time. Covers the data
-- years with a margin. Built with GENERATE_DATE_ARRAY, no package needed.
{{ config(materialized='table') }}
select date_day
from unnest(generate_date_array('2010-01-01', '2016-12-31', interval 1 day)) as date_day
