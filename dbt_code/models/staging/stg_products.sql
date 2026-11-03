with source as (

  select * from {{ source('raw_data', 'products') }}

),
enriched as (

  select
    p.product_id,
    p.product_name,
    p.category as product_category,
    p.subcategory as product_subcategory,
    coalesce(dm.department, 'Other') as product_department
  from source p
  left join {{ ref('category_to_department') }} dm
    on p.category = dm.category
)
select * from enriched

