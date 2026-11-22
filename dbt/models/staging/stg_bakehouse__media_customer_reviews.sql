-- Bronze layer: lightly cleaned, renamed pass-through of the raw
-- samples.bakehouse.media_customer_reviews source.
select
    franchiseID as franchise_id,
    review,
    review_date
from {{ source('bakehouse', 'media_customer_reviews') }}
