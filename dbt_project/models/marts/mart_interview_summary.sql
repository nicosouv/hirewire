{{ config(materialized='table') }}

WITH interview_stats AS (
    SELECT
        p.id as process_id,
        c.name as company_name,
        c.industry,
        c.size as company_size,
        jp.title as job_title,
        jp.level as job_level,
        jp.department,
        jp.remote_policy,
        p.application_date,
        p.status as process_status,
        p.source as application_source,
        COUNT(i.id) as total_interviews,
        AVG(i.duration_minutes) as avg_interview_duration,
        AVG(i.rating) as avg_interview_rating,
        STRING_AGG(DISTINCT i.interview_type, ', ') as interview_types,
        MIN(i.scheduled_date) as first_interview_date,
        MAX(i.scheduled_date) as last_interview_date,
        o.outcome,
        o.outcome_date,
        o.offer_salary,
        o.overall_experience_rating,
        CASE 
            WHEN o.outcome_date IS NOT NULL AND p.application_date IS NOT NULL 
            THEN o.outcome_date - p.application_date 
            ELSE NULL 
        END as process_duration_days
    FROM {{ ref('stg_interview_processes') }} p
    LEFT JOIN {{ ref('stg_job_positions') }} jp ON p.job_position_id = jp.id
    LEFT JOIN {{ ref('stg_companies') }} c ON jp.company_id = c.id
    LEFT JOIN {{ ref('stg_interviews') }} i ON p.id = i.process_id
    LEFT JOIN {{ ref('stg_interview_outcomes') }} o ON p.id = o.process_id
    GROUP BY 
        p.id, c.name, c.industry, c.size, jp.title, jp.level, jp.department, 
        jp.remote_policy, p.application_date, p.status, p.source,
        o.outcome, o.outcome_date, o.offer_salary, o.overall_experience_rating
)

SELECT 
    *,
    CASE 
        WHEN outcome = 'offer' THEN 'Success'
        WHEN outcome = 'rejection' THEN 'Rejection'
        WHEN outcome = 'ghosted' THEN 'Ghosted'
        WHEN outcome = 'withdrew' THEN 'Withdrew'
        WHEN process_status IN ('applied', 'screening', 'interviewing') THEN 'In Progress'
        ELSE 'Unknown'
    END as outcome_category
FROM interview_stats