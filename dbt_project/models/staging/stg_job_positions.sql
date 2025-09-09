{{ config(materialized='table') }}

SELECT
    id,
    company_id,
    title,
    department,
    level,
    employment_type,
    remote_policy,
    salary_min,
    salary_max,
    currency,
    created_at,
    updated_at
FROM {{ postgres_scan('job_positions') }}