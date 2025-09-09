{{ config(materialized='table') }}

-- Monthly trends and metrics for time-series analysis

WITH monthly_base AS (
    SELECT
        DATE_TRUNC('month', ip.application_date) as month,
        EXTRACT(year FROM ip.application_date) as year,
        EXTRACT(month FROM ip.application_date) as month_num,
        
        -- Applications
        COUNT(ip.process_id) as applications_count,
        COUNT(CASE WHEN ip.status_category = 'Success' THEN 1 END) as successful_applications,
        COUNT(CASE WHEN ip.status_category = 'Rejected' THEN 1 END) as rejected_applications,
        COUNT(CASE WHEN ip.status_category = 'In Progress' THEN 1 END) as active_applications,
        
        -- Interview metrics
        AVG(i.total_interviews) as avg_interviews_per_process,
        SUM(i.total_interviews) as total_interviews_conducted,
        AVG(i.avg_interview_duration) as avg_interview_duration,
        AVG(i.avg_interview_rating) as avg_interview_rating,
        
        -- Outcomes
        COUNT(CASE WHEN io.outcome_category IS NOT NULL THEN 1 END) as completed_processes,
        AVG(io.process_duration_days) as avg_process_duration,
        AVG(io.offer_salary) as avg_offer_salary,
        AVG(io.overall_experience_rating) as avg_experience_rating,
        
        -- Source breakdown
        COUNT(CASE WHEN ip.source_category = 'LinkedIn' THEN 1 END) as linkedin_applications,
        COUNT(CASE WHEN ip.source_category = 'Company Website' THEN 1 END) as website_applications,
        COUNT(CASE WHEN ip.source_category = 'Referral' THEN 1 END) as referral_applications,
        COUNT(CASE WHEN ip.source_category = 'Recruiter' THEN 1 END) as recruiter_applications,
        COUNT(CASE WHEN ip.source_category = 'Other' THEN 1 END) as other_applications,
        
        -- Industry breakdown  
        COUNT(CASE WHEN ip.industry = 'Tech' THEN 1 END) as tech_applications,
        COUNT(CASE WHEN ip.industry = 'Finance' THEN 1 END) as finance_applications,
        COUNT(CASE WHEN ip.industry LIKE '%Startup%' THEN 1 END) as startup_applications,
        
        CURRENT_TIMESTAMP as last_updated

    FROM {{ ref('int_interview_processes') }} ip
    LEFT JOIN {{ ref('int_interview_outcomes') }} io ON ip.process_id = io.process_id
    LEFT JOIN (
        -- Interview stats per process
        SELECT 
            process_id,
            COUNT(*) as total_interviews,
            AVG(duration_minutes) as avg_interview_duration,
            AVG(rating) as avg_interview_rating
        FROM {{ ref('int_interviews') }}
        GROUP BY process_id
    ) i ON ip.process_id = i.process_id
    
    WHERE ip.application_date IS NOT NULL
    GROUP BY 1, 2, 3
),

with_calculations AS (
    SELECT
        *,
        -- Success rates
        ROUND(
            successful_applications * 100.0 / 
            NULLIF(successful_applications + rejected_applications, 0), 
            1
        ) as success_rate_pct,
        
        -- Completion rates
        ROUND(
            completed_processes * 100.0 / NULLIF(applications_count, 0), 
            1
        ) as completion_rate_pct,
        
        -- Source distribution
        ROUND(linkedin_applications * 100.0 / NULLIF(applications_count, 0), 1) as linkedin_pct,
        ROUND(website_applications * 100.0 / NULLIF(applications_count, 0), 1) as website_pct,
        ROUND(referral_applications * 100.0 / NULLIF(applications_count, 0), 1) as referral_pct,
        ROUND(recruiter_applications * 100.0 / NULLIF(applications_count, 0), 1) as recruiter_pct,
        
        -- Month-over-month growth
        LAG(applications_count, 1) OVER (ORDER BY month) as prev_month_applications,
        
        -- Rolling averages (3-month)
        AVG(applications_count) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as rolling_3m_avg_applications,
        AVG(success_rate_pct) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as rolling_3m_avg_success_rate
        
    FROM monthly_base
)

SELECT
    *,
    -- Growth calculations
    CASE 
        WHEN prev_month_applications > 0 THEN
            ROUND((applications_count - prev_month_applications) * 100.0 / prev_month_applications, 1)
        ELSE NULL
    END as mom_applications_growth_pct,
    
    -- Seasonal indicators
    CASE 
        WHEN month_num IN (1, 2, 12) THEN 'Winter'
        WHEN month_num IN (3, 4, 5) THEN 'Spring'
        WHEN month_num IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END as season,
    
    -- Activity level
    CASE 
        WHEN applications_count >= rolling_3m_avg_applications * 1.2 THEN 'High'
        WHEN applications_count <= rolling_3m_avg_applications * 0.8 THEN 'Low'
        ELSE 'Normal'
    END as activity_level

FROM with_calculations
ORDER BY month DESC