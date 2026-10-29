with source_data as (
    select
        *
    from {{ source('raw_data', 'orders') }}
),

renamed as (
    select
        order_id::integer as order_id,
        customer_id::integer as customer_id,
        order_date::date as order_date,
        case
            when status = 'completed' then 'completed'
            when status = 'shipped' then 'in_transit'
            when status in ('pending', 'processing') then 'open'
            when status in ('cancelled', 'canceled', 'refunded') then 'cancelled'
            else 'other'
        end as order_status,
        lower(trim(shipping_method)) as shipping_method
    from source_data
)

select
    *
from renamed