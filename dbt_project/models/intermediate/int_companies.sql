{{ config(materialized='table') }}

SELECT
    id as company_id,
    TRIM(name) as company_name,
    COALESCE(industry, 'Unknown') as industry,
    CASE 
        WHEN size IS NULL THEN 'Unknown'
        WHEN size = '' THEN 'Unknown'
        ELSE size
    END as company_size,
    COALESCE(TRIM(location), 'Unknown') as location,
    website,
    created_at,
    updated_at
FROM {{ ref('stg_companies') }}
WHERE name IS NOT NULL 
    AND name != ''