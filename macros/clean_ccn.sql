{#
  A CMS Certification Number (CCN) is a 6-character string: 2-digit state code
  plus a 4-digit facility number. The charge files store it with the leading
  zero dropped ('70029' instead of '070029'), so a raw join to
  hospital_general_info silently loses every hospital in states 01-09
  (AL through CT). Pad it back to six characters.
#}
{% macro clean_ccn(column_name) -%}
  lpad(trim(cast({{ column_name }} as string)), 6, '0')
{%- endmacro %}
