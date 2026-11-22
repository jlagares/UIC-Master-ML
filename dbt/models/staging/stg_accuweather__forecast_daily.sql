-- Bronze layer: lightly cleaned, renamed pass-through of the raw
-- samples.accuweather source. No aggregation or business logic here.
select
    city_name,
    country_code,
    date as forecast_date,
    temperature_avg,
    temperature_max,
    temperature_min,
    round({{ fahrenheit_to_celsius('temperature_avg') }}, 1) as temperature_avg_c,
    humidity_relative_avg,
    precipitation_probability,
    has_precipitation,
    wind_speed_avg
from {{ source('accuweather', 'forecast_daily_calendar_imperial') }}
