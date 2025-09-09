{{ config(materialized='table') }}

SELECT
    company_id,
    company_name,
    industry,
    company_size,
    location,
    website,
    created_at,
    updated_at
FROM {{ ref('int_companies') }}
ORDER BY company_name