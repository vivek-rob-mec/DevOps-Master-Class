select cast(event_time as date) as event_date,country,currency,count(*) as order_count,sum(amount) as gross_amount
from {{ ref('stg_orders') }}
group by 1,2,3
