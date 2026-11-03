with orders as (

  select * from {{ ref('stg_orders') }}

),
payments as (
  select * from {{ ref('stg_payments') }}
),
order_payments as (
  select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.shipping_method,
    sum(case when p.payment_status = 'success' then p.payment_amount else 0 end) as gross_revenue,
    sum(case when p.payment_status = 'refund' then p.payment_amount else 0 end) as refund_amount,
    count(distinct p.payment_id) as payment_count,
    listagg(distinct p.payment_method, ', ')
      within group (order by p.payment_method) as payment_methods_used
  from orders o
  left join payments p
    on o.order_id = p.order_id
  group by
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.shipping_method
),
final as (
  select
    *,
    gross_revenue - refund_amount as net_revenue
  from order_payments
)
select * from final

