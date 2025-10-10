-- Test: Interview dates should follow logical temporal order
-- Ensures that:
-- 1. First interview date >= application date
-- 2. Last interview date >= first interview date
-- 3. Outcome date >= last interview date (if both exist)

WITH interview_timeline AS (
    SELECT
        m.process_id,
        m.company_name,
        m.job_title,
        m.application_date,
        m.first_interview_date,
        m.last_interview_date,
        m.outcome_date
    FROM {{ ref('mart_interview_summary') }} m
    WHERE
        m.first_interview_date IS NOT NULL
        OR m.last_interview_date IS NOT NULL
        OR m.outcome_date IS NOT NULL
),

date_violations AS (
    SELECT
        process_id,
        company_name,
        job_title,
        application_date,
        first_interview_date,
        last_interview_date,
        outcome_date,
        CASE
            WHEN first_interview_date < application_date
                THEN 'First interview (' || first_interview_date::TEXT || ') before application (' || application_date::TEXT || ')'
            WHEN last_interview_date < first_interview_date
                THEN 'Last interview (' || last_interview_date::TEXT || ') before first interview (' || first_interview_date::TEXT || ')'
            WHEN outcome_date IS NOT NULL AND last_interview_date IS NOT NULL AND outcome_date < last_interview_date
                THEN 'Outcome date (' || outcome_date::TEXT || ') before last interview (' || last_interview_date::TEXT || ')'
            WHEN outcome_date IS NOT NULL AND outcome_date < application_date
                THEN 'Outcome date (' || outcome_date::TEXT || ') before application (' || application_date::TEXT || ')'
        END as violation_reason
    FROM interview_timeline
    WHERE
        (first_interview_date < application_date)
        OR (last_interview_date < first_interview_date)
        OR (outcome_date IS NOT NULL AND last_interview_date IS NOT NULL AND outcome_date < last_interview_date)
        OR (outcome_date IS NOT NULL AND outcome_date < application_date)
)

-- This test fails if any temporal violations exist
SELECT * FROM date_violations