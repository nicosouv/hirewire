{{ config(materialized='table') }}

SELECT
    id,
    process_id,
    interview_type,
    interview_round,
    scheduled_date,
    actual_date,
    duration_minutes,
    interviewer_name,
    interviewer_role,
    status,
    feedback,
    rating,
    technical_topics,
    created_at,
    updated_at
FROM {{ postgres_scan('interviews') }}