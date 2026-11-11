{#-
  High-null guard. Passes when the share of NULLs in a column is at or below
  max_ratio. Use it on columns that are allowed to be sparse but where a jump
  in sparsity means the upstream extract broke (e.g. a whole year's ratings
  arriving as 'Not Available'). Returns one row (the failure) when over.
-#}
{% test null_proportion_at_most(model, column_name, max_ratio, where_clause=none) %}
with stats as (
    select
        countif({{ column_name }} is null) as null_rows,
        count(*) as total_rows
    from {{ model }}
    {% if where_clause %}where {{ where_clause }}{% endif %}
)
select
    null_rows,
    total_rows,
    safe_divide(null_rows, total_rows) as null_ratio
from stats
where safe_divide(null_rows, total_rows) > {{ max_ratio }}
{% endtest %}
