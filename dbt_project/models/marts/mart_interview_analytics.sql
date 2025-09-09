{{ config(materialized='table') }}

SELECT
    ip.company_name,
    ip.industry,
    ip.company_size,
    ip.job_title,
    ip.job_level,
    ip.remote_policy,
    COUNT(i.interview_id) as total_interviews,
    SUM(i.duration_minutes) as total_interview_duration_minutes,
    ip.days_since_application as process_duration_days,
    io.offer_salary,
    io.overall_experience_rating,
    ip.process_status,
    ip.status_category as outcome_category
FROM {{ ref('int_interview_processes') }} ip
LEFT JOIN {{ ref('int_interview_outcomes') }} io ON ip.process_id = io.process_id
LEFT JOIN {{ ref('int_interviews') }} i ON ip.process_id = i.process_id
GROUP BY 
    ip.company_name, ip.industry, ip.company_size, ip.job_title, 
    ip.job_level, ip.remote_policy, ip.days_since_application,
    io.offer_salary, io.overall_experience_rating, ip.process_status, ip.status_category