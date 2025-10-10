-- Test: Active applications should not have final outcomes
-- Validates that processes in mart_active_applications do not have
-- terminal outcomes (rejected, offer, accepted, ghosted, withdrew)
-- This ensures the active applications mart only shows truly active processes

WITH active_with_outcomes AS (
    SELECT
        a.process_id,
        a.company_name,
        a.job_title,
        a.current_status,
        o.outcome,
        o.outcome_category,
        o.outcome_date
    FROM {{ ref('mart_active_applications') }} a
    INNER JOIN {{ ref('int_interview_outcomes') }} o
        ON a.process_id = o.process_id
    WHERE
        -- Final/terminal outcomes
        o.outcome_category IN ('Success', 'Rejected', 'Withdrawn', 'Ghosted')
        OR o.outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'hired', 'ghosted', 'withdrew', 'withdrawn')
)

-- This test fails if any active applications have final outcomes
SELECT
    process_id,
    company_name,
    job_title,
    current_status,
    outcome,
    outcome_category,
    outcome_date,
    'Active application has final outcome: ' || outcome_category as violation_reason
FROM active_with_outcomes