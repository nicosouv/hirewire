{{ config(materialized='table') }}

SELECT
    jp.id as position_id,
    jp.company_id,
    c.company_name,
    c.industry,
    c.company_size,
    c.location as company_location,
    
    TRIM(jp.title) as job_title,
    COALESCE(jp.department, 'Unknown') as department,
    COALESCE(jp.level, 'Unknown') as job_level,
    COALESCE(jp.employment_type, 'Unknown') as employment_type,
    COALESCE(jp.remote_policy, 'Unknown') as remote_policy,
    
    jp.salary_min,
    jp.salary_max,
    COALESCE(jp.currency, 'EUR') as currency,
    
    -- Salary range calculation
    CASE 
        WHEN jp.salary_min IS NOT NULL AND jp.salary_max IS NOT NULL 
        THEN (jp.salary_min + jp.salary_max) / 2.0
        ELSE NULL
    END as avg_salary,
    
    jp.created_at,
    jp.updated_at

FROM {{ ref('stg_job_positions') }} jp
LEFT JOIN {{ ref('int_companies') }} c ON jp.company_id = c.company_id
WHERE jp.title IS NOT NULL 
    AND jp.title != ''