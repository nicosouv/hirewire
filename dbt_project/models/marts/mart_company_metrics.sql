{{ config(materialized='table') }}

-- Company-level metrics for analysis

SELECT
    c.company_name,
    c.industry,
    c.company_size,
    c.location,
    
    -- Application metrics
    COUNT(ip.process_id) as total_applications,
    COUNT(CASE WHEN ip.status_category = 'Success' THEN 1 END) as successful_applications,
    COUNT(CASE WHEN ip.status_category = 'In Progress' THEN 1 END) as active_applications,
    COUNT(CASE WHEN ip.status_category = 'Rejected' THEN 1 END) as rejected_applications,
    
    -- Success rates
    ROUND(
        COUNT(CASE WHEN ip.status_category = 'Success' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN ip.status_category IN ('Success', 'Rejected') THEN 1 END), 0), 
        1
    ) as success_rate_pct,
    
    -- Salary insights
    AVG(io.offer_salary) as avg_offer_salary,
    MIN(io.offer_salary) as min_offer_salary,
    MAX(io.offer_salary) as max_offer_salary,
    COUNT(CASE WHEN io.offer_salary IS NOT NULL THEN 1 END) as offers_with_salary,
    
    -- Process timing
    AVG(io.process_duration_days) as avg_process_duration_days,
    MIN(io.process_duration_days) as fastest_process_days,
    MAX(io.process_duration_days) as slowest_process_days,
    
    -- Interview metrics
    AVG(i.total_interviews) as avg_interviews_per_process,
    AVG(i.avg_interview_rating) as avg_interview_experience_rating,
    AVG(io.overall_experience_rating) as avg_overall_experience_rating,
    
    -- Recent activity
    MAX(ip.application_date) as last_application_date,
    COUNT(CASE WHEN ip.application_date >= CURRENT_DATE - INTERVAL '90 days' THEN 1 END) as applications_last_90_days,
    
    -- Source analysis
    STRING_AGG(DISTINCT ip.source_category, ', ') as application_sources_used,
    
    CURRENT_TIMESTAMP as last_updated

FROM {{ ref('int_companies') }} c
LEFT JOIN {{ ref('int_interview_processes') }} ip ON c.company_id = ip.company_id
LEFT JOIN {{ ref('int_interview_outcomes') }} io ON ip.process_id = io.process_id
LEFT JOIN (
    -- Interview stats per process
    SELECT 
        process_id,
        COUNT(*) as total_interviews,
        AVG(rating) as avg_interview_rating
    FROM {{ ref('int_interviews') }}
    GROUP BY process_id
) i ON ip.process_id = i.process_id

GROUP BY c.company_name, c.industry, c.company_size, c.location
HAVING COUNT(ip.process_id) > 0  -- Only companies with applications
ORDER BY total_applications DESC