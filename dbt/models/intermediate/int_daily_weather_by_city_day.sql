-- Silver layer: daily weather per city, with a sequential day index so it
-- can be aligned with the review timeline for correlation purposes. See
-- fct_weather_review_correlation_by_franchise.sql for why day_index is used
-- instead of calendar date.
with weather as (
    select * from {{ ref('stg_accuweather__forecast_daily') }}
)

select
    lower(trim(city_name)) as city_key,
    forecast_date,
    temperature_avg as temperature_f,
    temperature_avg_c as temperature_c,
    humidity_relative_avg as humidity_pct,
    precipitation_probability,
    row_number() over (
        partition by lower(trim(city_name)) order by forecast_date
    ) as day_index
from weather
