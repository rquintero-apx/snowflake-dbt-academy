with payment_data as (
    select
        *
    from {{ source('raw_data', 'payments') }}
),
payment_method_seed as (
    select
        *
    from {{ ref('payment_method_mapping') }}
),
final as (
    select
        p.payment_id::integer as payment_id,
        p.order_id::integer as order_id,
        coalesce(pm.payment_method_clean, 'other') as payment_method,
        -- Enforce precise financial decimal precision
        p.amount::decimal(10, 2) as payment_amount,
        lower(trim(p.status)) as payment_status
    from payment_data p
    left join payment_method_seed pm
        on lower(trim(p.payment_method)) = lower(pm.payment_method_raw)
)

select
    *
from final