-- Test: Priority score logic validation
-- Ensures that priority scores in mart_active_applications follow business rules:
-- 1. Offer stage should have highest priority (100)
-- 2. Priority scores should be within valid range (0-100)
-- 3. Upcoming scheduled interviews should have high priority (>= 85)

WITH priority_validations AS (
    SELECT
        process_id,
        company_name,
        job_title,
        current_status,
        next_scheduled_interview_date,
        priority_score,
        CASE
            -- Offers should always have priority 100
            WHEN current_status = 'offer' AND priority_score != 100
                THEN 'Offer status should have priority 100, found ' || priority_score::TEXT

            -- Priority must be in valid range
            WHEN priority_score < 0 OR priority_score > 100
                THEN 'Priority score out of range (0-100): ' || priority_score::TEXT

            -- Future scheduled interviews should have high priority
            WHEN next_scheduled_interview_date IS NOT NULL
                 AND next_scheduled_interview_date >= CURRENT_DATE
                 AND priority_score < 85
                THEN 'Future scheduled interview but priority only ' || priority_score::TEXT || ' (expected >= 85)'

            -- Processes with no activity should have lower priority
            WHEN days_since_application > 60
                 AND priority_score > 70
                 AND current_status = 'applied'
                 AND next_scheduled_interview_date IS NULL
                THEN 'Old application (>60 days) with no scheduled interviews but high priority: ' || priority_score::TEXT
        END as violation_reason
    FROM {{ ref('mart_active_applications') }}
)

-- This test fails if any priority score violations exist
SELECT
    process_id,
    company_name,
    job_title,
    current_status,
    next_scheduled_interview_date::TEXT as next_interview,
    priority_score,
    violation_reason
FROM priority_validations
WHERE violation_reason IS NOT NULL