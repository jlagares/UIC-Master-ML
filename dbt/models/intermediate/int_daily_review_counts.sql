-- Silver layer: daily review count + average sentiment score per franchise,
-- with a sequential day index (see int_daily_weather_by_city_day.sql) used
-- to align the review timeline with the city's weather timeline for
-- correlation purposes. Review count alone has almost no day-to-day
-- variance (franchises get ~1 review/day), so avg_sentiment_score is the
-- metric that actually carries signal for the gold-layer correlation.
with reviews as (
    select * from {{ ref('int_review_sentiment_scores') }}
),

franchises as (
    select * from {{ ref('stg_bakehouse__sales_franchises') }}
)

select
    f.franchise_id,
    f.franchise_name,
    lower(trim(f.city)) as city_key,
    r.review_date,
    count(r.review) as review_count,
    round(avg(r.sentiment_score), 2) as avg_sentiment_score,
    row_number() over (
        partition by f.franchise_id order by r.review_date
    ) as day_index
from franchises f
inner join reviews r on f.franchise_id = r.franchise_id
group by 1, 2, 3, 4
