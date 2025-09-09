{{ config(materialized='table') }}

WITH process_details AS (
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
        o.outcome,
        o.outcome_date,
        o.offer_salary,
        o.overall_experience_rating,
        CASE 
            WHEN o.outcome_date IS NOT NULL AND p.application_date IS NOT NULL 
            THEN (o.outcome_date - p.application_date) 
            ELSE NULL 
        END as process_duration_days
    FROM {{ postgres_scan('interview_processes') }} p
    LEFT JOIN {{ postgres_scan('job_positions') }} jp 
        ON p.job_position_id = jp.id
    LEFT JOIN {{ postgres_scan('companies') }} c 
        ON jp.company_id = c.id
    LEFT JOIN {{ postgres_scan('interview_outcomes') }} o 
        ON p.id = o.process_id
),

interview_stats AS (
    SELECT
        process_id,
        COUNT(*) as total_interviews,
        AVG(duration_minutes) as avg_interview_duration,
        AVG(rating) as avg_interview_rating,
        STRING_AGG(DISTINCT interview_type, ', ') as interview_types,
        MIN(scheduled_date) as first_interview_date,
        MAX(scheduled_date) as last_interview_date
    FROM {{ postgres_scan('interviews') }}
    GROUP BY process_id
)

SELECT 
    pd.*,
    COALESCE(ist.total_interviews, 0) as total_interviews,
    ist.avg_interview_duration,
    ist.avg_interview_rating,
    ist.interview_types,
    ist.first_interview_date,
    ist.last_interview_date,
    CASE 
        WHEN outcome = 'offer' THEN 'Success'
        WHEN outcome = 'rejection' THEN 'Rejection'
        WHEN outcome = 'ghosted' THEN 'Ghosted'
        WHEN outcome = 'withdrew' THEN 'Withdrew'
        WHEN process_status IN ('applied', 'screening', 'interviewing') THEN 'In Progress'
        ELSE 'Unknown'
    END as outcome_category,
    CURRENT_TIMESTAMP as created_at
FROM process_details pd
LEFT JOIN interview_stats ist ON pd.process_id = ist.process_id