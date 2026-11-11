{{ config(cluster_by=['provider_state', 'provider_type']) }}
-- Grain: one row per NPI.
select
    *,
    case entity_code when 'I' then 'individual' when 'O' then 'organization' end as entity_type
from {{ ref('int_physicians__latest') }}
