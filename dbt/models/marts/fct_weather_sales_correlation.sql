-- Gold layer: franchise review volume correlated with the weather in its
-- city for the same month. Demonstrates joining two silver marts into a
-- single business-ready table.
with reviews as (
    select * from {{ ref('int_franchise_review_summary') }}
),

weather as (
    select * from {{ ref('int_daily_weather_by_city') }}
)

select
    r.franchise_id,
    r.franchise_name,
    r.city_key,
    r.review_month,
    r.review_count,
    w.avg_temperature_f,
    w.avg_temperature_c,
    w.avg_humidity_pct,
    w.avg_precipitation_probability
from reviews r
left join weather w
    on r.city_key = w.city_key
    and r.review_month = w.weather_month
