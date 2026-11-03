with line_items as (

    select * from {{ ref('stg_line_items') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

final as (

    select
        li.order_id,
        li.product_id,
        p.product_name,
        p.product_category,
        p.product_subcategory,
        p.product_department,
        li.quantity,
        li.unit_price,
        li.discount_pct,
        li.line_total,
        li.line_total_after_discount
    from line_items li
    inner join products p
        on li.product_id = p.product_id

)

select * from final
