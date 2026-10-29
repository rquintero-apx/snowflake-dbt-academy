with source as (

    select * from {{ source('raw_data', 'web_events') }}

),

flattened as (

    select
        event_id,
        received_at,
        payload:event_type::string as event_type,
        payload:user_id::integer as user_id,
        payload:page::string as page_url,
        payload:product_id::integer as product_id,
        payload:quantity::integer as quantity,
        payload:order_id::integer as order_id,
        payload:total::decimal(10,2) as order_total,

        -- Nested device object
        payload:device:type::string as device_type,
        payload:device:browser::string as browser,
        payload:device:os::string as os,

        -- Nested UTM object (nullable)
        payload:utm:source::string as utm_source,
        payload:utm:medium::string as utm_medium,
        payload:utm:campaign::string as utm_campaign
    from source

)

select * from flattened
