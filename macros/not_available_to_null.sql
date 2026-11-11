{#
  hospital_general_info encodes missing values as the literal string
  'Not Available'. Turn that into NULL, never 0: a hospital with no star rating
  is unrated, not a zero-star hospital.
#}
{% macro not_available_to_int(column_name) -%}
  safe_cast(nullif(trim({{ column_name }}), 'Not Available') as int64)
{%- endmacro %}
