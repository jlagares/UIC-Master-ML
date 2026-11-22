-- Gold layer / GenAI step: use ai_query() to turn the weather+review
-- correlation into a one-sentence, human-readable insight per
-- franchise/month. Mirrors the sentiment-classification pattern in
-- Notebooks/From Table to GenAI.ipynb (LOWER() + ai_query()).
select
    franchise_id,
    franchise_name,
    city_key,
    review_month,
    review_count,
    avg_temperature_f,
    avg_humidity_pct,
    lower(ai_query(
        'databricks-meta-llama-3-1-8b-instruct',
        concat(
            'In one short sentence, describe how the weather (avg temperature ',
            cast(round(avg_temperature_f, 0) as string), 'F, humidity ',
            cast(round(avg_humidity_pct, 0) as string), '%) may have influenced the ',
            cast(review_count as string), ' customer reviews received by ',
            franchise_name, ' this month. Respond with a single concise sentence.'
        )
    )) as weather_sales_insight
from {{ ref('fct_weather_sales_correlation') }}
where avg_temperature_f is not null
