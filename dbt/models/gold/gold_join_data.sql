select
    *,
    case
        when monthly_charge < 20 then '<20'
        when monthly_charge < 50 then '20-50'
        when monthly_charge < 100 then '50-100'
        else '>100'
    end as monthly_charge_range
from {{ ref('silver_customers') }}
where customer_status = 'Joined'
