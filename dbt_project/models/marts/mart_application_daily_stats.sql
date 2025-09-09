{{ config(materialized='table') }}

WITH daily_applications AS (
    SELECT
        DATE_TRUNC('day', application_date) as day,
        COUNT(*) as applications_count,
        COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejections_count,
        COUNT(CASE WHEN status = 'offer' THEN 1 END) as offers_count,
        COUNT(CASE WHEN status = 'accepted' THEN 1 END) as accepted_count,
        AVG(CASE
            WHEN o.outcome_date IS NOT NULL AND p.application_date IS NOT NULL
            THEN o.outcome_date - p.application_date
            ELSE NULL
        END) as avg_process_duration_days,
        AVG(o.offer_salary) as avg_offer_salary,
        AVG(o.overall_experience_rating) as avg_experience_rating
    FROM {{ ref('stg_interview_processes') }} p
    LEFT JOIN {{ ref('stg_interview_outcomes') }} o ON p.id = o.process_id
    WHERE application_date IS NOT NULL
    GROUP BY DATE_TRUNC('day', application_date)
),

daily_interviews AS (
    SELECT
        DATE_TRUNC('day', scheduled_date) as day,
        COUNT(*) as interviews_count,
        AVG(duration_minutes) as avg_interview_duration,
        AVG(rating) as avg_interview_rating,
        COUNT(CASE WHEN interview_type = 'technical' THEN 1 END) as technical_interviews_count,
        COUNT(CASE WHEN interview_type = 'behavioral' THEN 1 END) as behavioral_interviews_count
    FROM {{ ref('stg_interviews') }}
    WHERE scheduled_date IS NOT NULL
    GROUP BY DATE_TRUNC('day', scheduled_date)
)

SELECT
    COALESCE(a.day, i.day) as day,
    COALESCE(a.applications_count, 0) as applications_count,
    COALESCE(a.rejections_count, 0) as rejections_count,
    COALESCE(a.offers_count, 0) as offers_count,
    COALESCE(a.accepted_count, 0) as accepted_count,
    COALESCE(i.interviews_count, 0) as interviews_count,
    COALESCE(i.technical_interviews_count, 0) as technical_interviews_count,
    COALESCE(i.behavioral_interviews_count, 0) as behavioral_interviews_count,
    a.avg_process_duration_days,
    a.avg_offer_salary,
    a.avg_experience_rating,
    i.avg_interview_duration,
    i.avg_interview_rating,
    CASE
        WHEN a.applications_count > 0
        THEN ROUND((a.offers_count::FLOAT / a.applications_count::FLOAT) * 100, 2)
        ELSE 0
    END as offer_rate_percentage,
    CASE
        WHEN a.applications_count > 0
        THEN ROUND((a.rejections_count::FLOAT / a.applications_count::FLOAT) * 100, 2)
        ELSE 0
    END as rejection_rate_percentage
FROM daily_applications a
FULL OUTER JOIN daily_interviews i ON a.day = i.day
ORDER BY day