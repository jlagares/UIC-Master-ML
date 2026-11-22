-- Silver layer: weather "snapshot" aggregate per city.
--
-- NOTE: samples.accuweather forecast/historical tables are rolling windows
-- relative to "today" (always ~ -2 weeks to +2 weeks), not a fixed historical
-- archive. They will never share an exact calendar month with the static
-- samples.bakehouse review dates (fixed around May 2024). We therefore
-- aggregate to one row per city (latest available conditions) instead of
-- per city+month, and correlate on city only in the gold layer.
with weather as (
    select * from {{ ref('stg_accuweather__forecast_daily') }}
)

select
    lower(trim(city_name)) as city_key,
    min(forecast_date) as observed_from,
    max(forecast_date) as observed_to,
    round(avg(temperature_avg), 1) as avg_temperature_f,
    round(avg(temperature_avg_c), 1) as avg_temperature_c,
    round(avg(humidity_relative_avg), 1) as avg_humidity_pct,
    round(avg(precipitation_probability), 1) as avg_precipitation_probability,
    count(*) as days_observed
from weather
group by 1
