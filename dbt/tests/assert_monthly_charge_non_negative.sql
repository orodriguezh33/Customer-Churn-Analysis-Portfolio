{{ config(severity = 'warn') }}

select *
from {{ ref('silver_customers') }}
where monthly_charge < 0
