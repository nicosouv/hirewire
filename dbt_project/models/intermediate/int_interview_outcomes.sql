{{ config(materialized='table') }}

SELECT
    io.id as outcome_id,
    io.process_id,
    ip.company_name,
    ip.job_title,
    ip.application_source,
    
    TRIM(LOWER(io.outcome)) as outcome,
    io.outcome_date,
    io.offer_salary,
    COALESCE(io.offer_currency, 'EUR') as offer_currency,
    io.rejection_reason,
    io.feedback_received,
    io.would_reapply,
    io.overall_experience_rating,
    io.notes,
    
    -- Process duration
    CASE 
        WHEN io.outcome_date IS NOT NULL AND ip.application_date IS NOT NULL
        THEN io.outcome_date - ip.application_date
        ELSE NULL
    END as process_duration_days,
    
    -- Outcome categorization
    CASE 
        WHEN TRIM(LOWER(io.outcome)) IN ('offer', 'accepted', 'hired') THEN 'Success'
        WHEN TRIM(LOWER(io.outcome)) IN ('rejected', 'rejected_by_company', 'failed') THEN 'Rejected'
        WHEN TRIM(LOWER(io.outcome)) IN ('withdrew', 'withdrawn', 'rejected_by_candidate') THEN 'Withdrawn'
        WHEN TRIM(LOWER(io.outcome)) IN ('ghosted', 'no_response') THEN 'Ghosted'
        ELSE 'Other'
    END as outcome_category,
    
    -- Experience rating categorization
    CASE 
        WHEN io.overall_experience_rating >= 4 THEN 'Excellent Experience'
        WHEN io.overall_experience_rating >= 3 THEN 'Good Experience'
        WHEN io.overall_experience_rating >= 2 THEN 'Average Experience'
        WHEN io.overall_experience_rating >= 1 THEN 'Poor Experience'
        ELSE 'Not Rated'
    END as experience_category,
    
    -- Duration categorization
    CASE 
        WHEN io.outcome_date IS NOT NULL AND ip.application_date IS NOT NULL THEN
            CASE 
                WHEN (io.outcome_date - ip.application_date) <= 7 THEN 'Very Fast (≤1 week)'
                WHEN (io.outcome_date - ip.application_date) <= 14 THEN 'Fast (1-2 weeks)'
                WHEN (io.outcome_date - ip.application_date) <= 30 THEN 'Normal (2-4 weeks)'
                WHEN (io.outcome_date - ip.application_date) <= 60 THEN 'Slow (1-2 months)'
                ELSE 'Very Slow (>2 months)'
            END
        ELSE 'Unknown'
    END as process_speed_category,
    
    io.created_at,
    io.updated_at

FROM {{ ref('stg_interview_outcomes') }} io
LEFT JOIN {{ ref('int_interview_processes') }} ip ON io.process_id = ip.process_id
WHERE io.process_id IS NOT NULL