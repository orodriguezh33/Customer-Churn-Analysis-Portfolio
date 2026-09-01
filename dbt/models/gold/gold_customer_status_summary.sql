select
    customer_status,
    count(*) as customer_count,
    round(count(*) * 100.0 / sum(count(*)) over (), 2) as pct_of_total
from {{ ref('silver_customers') }}
group by customer_status
