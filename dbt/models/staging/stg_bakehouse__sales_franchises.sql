-- Bronze layer: lightly cleaned, renamed pass-through of the raw
-- samples.bakehouse.sales_franchises source.
select
    franchiseID as franchise_id,
    name as franchise_name,
    city,
    district,
    country,
    latitude,
    longitude
from {{ source('bakehouse', 'sales_franchises') }}
