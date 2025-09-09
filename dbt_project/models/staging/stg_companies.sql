{{ config(materialized='table') }}

SELECT
    id,
    name,
    industry,
    size,
    location,
    website,
    created_at,
    updated_at
FROM {{ postgres_scan('companies') }}