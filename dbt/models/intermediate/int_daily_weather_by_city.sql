-- Silver layer: monthly weather aggregate per city.
-- Aggregation keeps the gold-layer join cheap and the grain predictable.
with weather as (
    select * from {{ ref('stg_accuweather__forecast_daily') }}
)

select
    lower(trim(city_name)) as city_key,
    date_trunc('month', forecast_date) as weather_month,
    round(avg(temperature_avg), 1) as avg_temperature_f,
    round(avg(temperature_avg_c), 1) as avg_temperature_c,
    round(avg(humidity_relative_avg), 1) as avg_humidity_pct,
    round(avg(precipitation_probability), 1) as avg_precipitation_probability,
    count(*) as days_observed
from weather
group by 1, 2
