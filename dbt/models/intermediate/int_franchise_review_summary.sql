-- Silver layer: monthly customer-review aggregate per franchise.
-- Follows repo convention: COLLECT_LIST() + COUNT() for review rollups
-- (see Notebooks/From Table to GenAI.ipynb).
with reviews as (
    select * from {{ ref('stg_bakehouse__media_customer_reviews') }}
),

franchises as (
    select * from {{ ref('stg_bakehouse__sales_franchises') }}
)

select
    f.franchise_id,
    f.franchise_name,
    lower(trim(f.city)) as city_key,
    date_trunc('month', r.review_date) as review_month,
    count(r.review) as review_count,
    collect_list(r.review) as reviews
from franchises f
inner join reviews r on f.franchise_id = r.franchise_id
group by 1, 2, 3, 4
