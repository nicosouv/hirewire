{{ config(materialized='table') }}

SELECT
    i.id as interview_id,
    i.process_id,
    ip.company_name,
    ip.job_title,
    ip.process_status,
    
    TRIM(i.interview_type) as interview_type,
    i.interview_round,
    i.scheduled_date,
    i.actual_date,
    i.duration_minutes,
    
    -- Interviewer info
    TRIM(i.interviewer_name) as interviewer_name,
    TRIM(i.interviewer_role) as interviewer_role,
    
    TRIM(LOWER(i.status)) as interview_status,
    i.feedback,
    i.rating,
    i.technical_topics,
    
    -- Enrichments
    CASE 
        WHEN i.actual_date IS NOT NULL AND i.scheduled_date IS NOT NULL
        THEN CAST((i.actual_date - i.scheduled_date) AS INTEGER)
        ELSE 0
    END as reschedule_days,
    
    CASE 
        WHEN TRIM(LOWER(i.interview_type)) LIKE '%technical%' THEN 'Technical'
        WHEN TRIM(LOWER(i.interview_type)) LIKE '%behavioral%' THEN 'Behavioral' 
        WHEN TRIM(LOWER(i.interview_type)) LIKE '%hr%' THEN 'HR'
        WHEN TRIM(LOWER(i.interview_type)) LIKE '%manager%' THEN 'Manager'
        WHEN TRIM(LOWER(i.interview_type)) LIKE '%cultural%' OR TRIM(LOWER(i.interview_type)) LIKE '%culture%' THEN 'Cultural'
        ELSE 'Other'
    END as interview_category,
    
    -- Duration categories
    CASE 
        WHEN i.duration_minutes <= 30 THEN 'Short (≤30min)'
        WHEN i.duration_minutes <= 60 THEN 'Standard (30-60min)'
        WHEN i.duration_minutes <= 90 THEN 'Long (60-90min)'
        WHEN i.duration_minutes > 90 THEN 'Extended (>90min)'
        ELSE 'Unknown'
    END as duration_category,
    
    -- Rating categories
    CASE 
        WHEN i.rating >= 4 THEN 'Excellent'
        WHEN i.rating >= 3 THEN 'Good'
        WHEN i.rating >= 2 THEN 'Average'
        WHEN i.rating >= 1 THEN 'Poor'
        ELSE 'Not Rated'
    END as rating_category,
    
    i.created_at,
    i.updated_at

FROM {{ ref('stg_interviews') }} i
LEFT JOIN {{ ref('int_interview_processes') }} ip ON i.process_id = ip.process_id
WHERE i.process_id IS NOT NULL