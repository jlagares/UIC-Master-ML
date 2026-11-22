-- Silver layer / GenAI step: classify each individual customer review's
-- sentiment via ai_query(), then map it to a numeric score so sentiment can
-- be correlated with weather at the franchise level. Mirrors the
-- sentiment-classification pattern in Notebooks/From Table to GenAI.ipynb
-- (LOWER() + ai_query()).
with reviews as (
    select * from {{ ref('stg_bakehouse__media_customer_reviews') }}
),

classified as (
    select
        franchise_id,
        review_date,
        review,
        lower(ai_query(
            'databricks-meta-llama-3-1-8b-instruct',
            concat(
                'Classify the sentiment of this customer review as exactly ',
                'one word: positive, neutral, or negative. Review: ', review
            )
        )) as sentiment_label
    from reviews
)

select
    franchise_id,
    review_date,
    review,
    sentiment_label,
    case
        when sentiment_label like '%positive%' then 1
        when sentiment_label like '%negative%' then -1
        else 0
    end as sentiment_score
from classified
