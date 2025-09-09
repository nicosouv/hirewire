{{ config(materialized='table') }}

SELECT
    id,
    process_id,
    outcome,
    outcome_date,
    offer_salary,
    offer_currency,
    rejection_reason,
    feedback_received,
    would_reapply,
    overall_experience_rating,
    notes,
    created_at,
    updated_at
FROM {{ postgres_scan('interview_outcomes') }}