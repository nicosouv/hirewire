{{ config(materialized='table') }}

-- Main dashboard table for Metabase
-- Combines all interview process data with enriched dimensions

WITH process_summary AS (
    SELECT
        ip.process_id,
        ip.company_name,
        ip.industry,
        ip.company_size,
        ip.job_title,
        ip.job_level,
        ip.department,
        ip.remote_policy,
        ip.application_date,
        ip.application_source,
        ip.source_category,
        ip.process_status,
        ip.status_category,
        ip.days_since_application,
        
        -- Outcome information
        io.outcome_category,
        io.outcome_date,
        io.process_duration_days,
        io.offer_salary,
        io.offer_currency,
        io.overall_experience_rating,
        io.experience_category,
        io.process_speed_category,
        io.feedback_received,
        io.would_reapply,
        
        -- Interview statistics
        COUNT(i.interview_id) as total_interviews,
        AVG(i.duration_minutes) as avg_interview_duration,
        AVG(i.rating) as avg_interview_rating,
        STRING_AGG(DISTINCT i.interview_category, ', ') as interview_types,
        MIN(i.scheduled_date) as first_interview_date,
        MAX(i.scheduled_date) as last_interview_date,
        SUM(i.duration_minutes) as total_interview_time,
        
        -- Success metrics
        CASE 
            WHEN io.outcome_category = 'Success' THEN 1
            ELSE 0
        END as is_success,
        
        CASE 
            WHEN io.outcome_category IN ('Success', 'Rejected', 'Withdrawn', 'Ghosted') THEN 1
            ELSE 0
        END as is_completed

    FROM {{ ref('int_interview_processes') }} ip
    LEFT JOIN {{ ref('int_interview_outcomes') }} io ON ip.process_id = io.process_id
    LEFT JOIN {{ ref('int_interviews') }} i ON ip.process_id = i.process_id
    GROUP BY 
        ip.process_id, ip.company_name, ip.industry, ip.company_size, 
        ip.job_title, ip.job_level, ip.department, ip.remote_policy,
        ip.application_date, ip.application_source, ip.source_category,
        ip.process_status, ip.status_category, ip.days_since_application,
        io.outcome_category, io.outcome_date, io.process_duration_days,
        io.offer_salary, io.offer_currency, io.overall_experience_rating,
        io.experience_category, io.process_speed_category, 
        io.feedback_received, io.would_reapply
),

enriched_summary AS (
    SELECT
        *,
        -- Salary analysis
        CASE 
            WHEN offer_salary IS NOT NULL THEN 
                CASE 
                    WHEN offer_salary < 40000 THEN 'Low (<40k)'
                    WHEN offer_salary < 60000 THEN 'Medium (40-60k)'
                    WHEN offer_salary < 80000 THEN 'Good (60-80k)'
                    WHEN offer_salary < 100000 THEN 'High (80-100k)'
                    ELSE 'Very High (>100k)'
                END
            ELSE 'Not Disclosed'
        END as salary_range,
        
        -- Time-based analysis
        DATE_TRUNC('month', application_date) as application_month,
        DATE_TRUNC('quarter', application_date) as application_quarter,
        EXTRACT(year FROM application_date) as application_year,
        EXTRACT(month FROM application_date) as application_month_num,
        EXTRACT(dow FROM application_date) as application_day_of_week,
        
        -- Interview intensity
        CASE 
            WHEN total_interviews = 0 THEN 'No Interviews'
            WHEN total_interviews <= 2 THEN 'Light (1-2)'
            WHEN total_interviews <= 4 THEN 'Medium (3-4)'
            WHEN total_interviews <= 6 THEN 'Heavy (5-6)'
            ELSE 'Very Heavy (7+)'
        END as interview_intensity,
        
        -- Process efficiency score (higher is better)
        CASE 
            WHEN is_completed = 1 AND process_duration_days IS NOT NULL THEN
                CASE 
                    WHEN outcome_category = 'Success' AND process_duration_days <= 14 THEN 10
                    WHEN outcome_category = 'Success' AND process_duration_days <= 30 THEN 8
                    WHEN outcome_category = 'Success' THEN 6
                    WHEN outcome_category = 'Rejected' AND process_duration_days <= 7 THEN 8  -- Quick rejection is good
                    WHEN outcome_category = 'Rejected' AND process_duration_days <= 14 THEN 6
                    WHEN outcome_category = 'Rejected' THEN 4
                    WHEN outcome_category = 'Ghosted' THEN 1
                    ELSE 3
                END
            ELSE NULL
        END as process_efficiency_score,
        
        CURRENT_TIMESTAMP as last_updated
        
    FROM process_summary
)

SELECT * FROM enriched_summary
ORDER BY application_date DESC