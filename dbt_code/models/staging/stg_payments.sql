with source_data as (
    select
        *
    from {{ source('raw_data', 'payments') }}
),

renamed as (
    select
        payment_id::integer as payment_id,
        order_id::integer as order_id,
        case
            when lower(trim(payment_method)) in ('credit_card', 'cc', 'visa', 'mastercard', 'amex') then 'credit_card'
            when lower(trim(payment_method)) in ('bank_transfer', 'wire', 'ach') then 'bank_transfer'
            when lower(trim(payment_method)) in ('paypal', 'venmo') then 'digital_wallet'
            when lower(trim(payment_method)) = 'gift_card' then 'gift_card'
            else 'other'
        end as payment_method,
        -- Enforce precise financial decimal precision
        amount::decimal(10, 2) as payment_amount,
        lower(trim(status)) as payment_status
    from source_data
)

select
    *
from renamed