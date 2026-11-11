{#
  The free BigQuery sandbox forces a 60-day expiration on DATE/TIMESTAMP
  partitions, and refuses to let a table override it. Historical data (2022
  taxi trips) is older than 60 days, so every partition is deleted as soon
  as it is written and the table comes out empty.

  The sandbox also rejects DML (INSERT, MERGE, DELETE), so incremental
  models cannot run there; fct_taxi_trips falls back to a full table build.

  Integer-range partitions are not subject to the expiration rule. With
  DBT_BQ_SANDBOX=true, time-partitioned models switch to an INT64
  day-number partition (UNIX_DATE). On a billed project, leave it unset and
  they use native DATE partitioning.
#}
{% macro is_bq_sandbox() -%}
  {{ return(env_var('DBT_BQ_SANDBOX', 'false') | lower in ['true', '1', 'yes']) }}
{%- endmacro %}

{# Days since 1970-01-01 for an ISO date string, evaluated at compile time. #}
{% macro unix_day(iso_date) -%}
  {%- set d = modules.datetime.date.fromisoformat(iso_date) -%}
  {{ return(d.toordinal() - modules.datetime.date(1970, 1, 1).toordinal()) }}
{%- endmacro %}

{# partition_by config for a daily partition on pickup_date / pickup_unix_day. #}
{% macro daily_partition_config(date_field, day_number_field, start_date, end_date) -%}
  {%- if is_bq_sandbox() -%}
    {{ return({
        'field': day_number_field,
        'data_type': 'int64',
        'range': {'start': unix_day(start_date), 'end': unix_day(end_date), 'interval': 1}
    }) }}
  {%- else -%}
    {{ return({'field': date_field, 'data_type': 'date', 'granularity': 'day'}) }}
  {%- endif -%}
{%- endmacro %}
