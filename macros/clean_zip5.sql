{#
  CMS zip codes arrive in three shapes across the yearly files:
    '02134'   (string, correct)
    '99519.0' (2013 inpatient: a float that was cast to string)
    2134      (2015 outpatient: INT64, so New England zips lost the leading zero)
  This normalizes all three to a 5-character string.
#}
{% macro clean_zip5(column_name) -%}
  lpad(left(regexp_replace(trim(cast({{ column_name }} as string)), r'\.0+$', ''), 5), 5, '0')
{%- endmacro %}
