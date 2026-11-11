{#- Fails for each row where the expression is false. NULLs pass unless the expression handles them. -#}
{% test expression_is_true(model, expression, column_name=none) %}
select *
from {{ model }}
where not ({{ expression }})
{% endtest %}
