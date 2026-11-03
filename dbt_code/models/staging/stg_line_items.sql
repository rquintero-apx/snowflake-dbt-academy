with source as (
  select * from {{ source('raw_data', 'line_items') }}
),

calculated as (

  select
    order_id,
    product_id,
    quantity,
    unit_price,
    coalesce(discount_pct, 0) as discount_pct,
    quantity * unit_price as line_total,
    quantity * unit_price * (1 - coalesce(discount_pct, 0) / 100) as line_total_after_discount
  from source

)
select * from calculated
