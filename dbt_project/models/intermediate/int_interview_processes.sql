{{ config(materialized='table') }}

WITH enriched_processes AS (
    SELECT
        ip.id as process_id,
        ip.job_position_id,
        jp.company_id,
        jp.company_name,
        jp.industry,
        jp.company_size,
        jp.job_title,
        jp.job_level,
        jp.department,
        jp.remote_policy,
        
        ip.application_date,
        TRIM(LOWER(ip.status)) as process_status,
        TRIM(LOWER(ip.source)) as application_source,
        ip.notes,
        
        -- Date calculations
        CURRENT_DATE - ip.application_date as days_since_application,
        
        -- Status categorization
        CASE 
            WHEN TRIM(LOWER(ip.status)) IN ('offer', 'accepted') THEN 'Success'
            WHEN TRIM(LOWER(ip.status)) IN ('rejected', 'failed') THEN 'Rejected'
            WHEN TRIM(LOWER(ip.status)) IN ('applied', 'screening', 'interviewing', 'final_round') THEN 'In Progress'
            WHEN TRIM(LOWER(ip.status)) IN ('withdrew', 'withdrawn') THEN 'Withdrawn'
            ELSE 'Other'
        END as status_category,
        
        -- Source categorization  
        CASE 
            WHEN TRIM(LOWER(ip.source)) LIKE '%linkedin%' THEN 'LinkedIn'
            WHEN TRIM(LOWER(ip.source)) LIKE '%indeed%' THEN 'Indeed'
            WHEN TRIM(LOWER(ip.source)) LIKE '%website%' THEN 'Company Website'
            WHEN TRIM(LOWER(ip.source)) LIKE '%referral%' THEN 'Referral'
            WHEN TRIM(LOWER(ip.source)) LIKE '%recruiter%' THEN 'Recruiter'
            ELSE 'Other'
        END as source_category,
        
        ip.created_at,
        ip.updated_at

    FROM {{ ref('stg_interview_processes') }} ip
    LEFT JOIN {{ ref('int_job_positions') }} jp ON ip.job_position_id = jp.position_id
)

SELECT * FROM enriched_processes
WHERE application_date IS NOT NULL