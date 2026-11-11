{#- Fails for each non-null value that does not fully match the pattern. -#}
{% test matches_regex(model, column_name, pattern) %}
select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and not regexp_contains(cast({{ column_name }} as string), r'^(?:{{ pattern }})$')
{% endtest %}
