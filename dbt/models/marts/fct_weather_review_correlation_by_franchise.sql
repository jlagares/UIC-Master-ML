-- Gold layer: per-franchise correlation between daily review sentiment /
-- volume and daily weather, to check whether weather "really impacts"
-- reviews at the individual franchise ("customer") level.
--
-- WHY day_index, not calendar date: samples.accuweather is a rolling window
-- relative to "today" while samples.bakehouse reviews are fixed in May 2024
-- (see the "Data caveat" in README.md / ClassScript.md). There is no shared
-- calendar date to join on. As a teaching proxy, we line up each franchise's
-- Nth day of reviews with the Nth day of its city's available weather
-- (day_index), which lets us compute a real Pearson correlation coefficient
-- (CORR()) per franchise. Treat the result as a directional classroom
-- illustration, not a statistically validated causal measurement — each
-- franchise typically has well under 20 matched days, so we require at
-- least 3 matched days before surfacing a coefficient.
--
-- WHY sentiment, not just review count: daily review volume per franchise
-- barely varies (almost always 1 review/day), so CORR() against volume is
-- usually NULL (no variance to correlate). Review sentiment (-1/0/+1, via
-- ai_query() in int_review_sentiment_scores.sql) does vary day to day, so
-- it's the metric that can actually show a weather relationship.
with reviews as (
    select * from {{ ref('int_daily_review_counts') }}
),

weather as (
    select * from {{ ref('int_daily_weather_by_city_day') }}
)

select
    r.franchise_id,
    r.franchise_name,
    r.city_key,
    count(*) as matched_days,
    round(corr(r.review_count, w.temperature_f), 3) as volume_temp_correlation,
    round(corr(r.avg_sentiment_score, w.temperature_f), 3) as sentiment_temp_correlation,
    round(corr(r.avg_sentiment_score, w.humidity_pct), 3) as sentiment_humidity_correlation,
    round(avg(r.review_count), 2) as avg_daily_reviews,
    round(avg(r.avg_sentiment_score), 2) as avg_sentiment_score,
    round(avg(w.temperature_f), 1) as avg_daily_temperature_f
from reviews r
inner join weather w
    on r.city_key = w.city_key
    and r.day_index = w.day_index
group by 1, 2, 3
having count(*) >= 3
