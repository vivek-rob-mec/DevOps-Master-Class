select event_id,event_time,customer_id,upper(country) as country,amount,upper(currency) as currency,ingested_at
from {{ source('platform','raw_orders') }}
where amount > 0
