with source_data as (
    select
        *
    from {{ source('raw_data', 'customers') }}
),

cleaned as (
    select
        customer_id::integer as customer_id,
        trim(upper(first_name)) as first_name,
        trim(upper(last_name)) as last_name,
        trim(lower(email)) as email,
        coalesce(trim(phone), 'N/A') as phone_number,
        trim(upper(country)) as country_code,
        created_at::timestamp_ntz as created_at
    from source_data
    where created_at is not null
      and email is not null
      and email like '%@%'
    qualify row_number() over (
        partition by trim(lower(email))
        order by created_at desc
    ) = 1
)

select
    *
from cleaned