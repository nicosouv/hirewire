-- Test: Each process should have at most one outcome
-- Business rule: A process can only have one final outcome
-- This is a critical data integrity test

WITH outcome_counts AS (
    SELECT
        process_id,
        COUNT(*) as outcome_count
    FROM {{ ref('int_interview_outcomes') }}
    GROUP BY process_id
    HAVING COUNT(*) > 1
),

duplicate_outcomes AS (
    SELECT
        oc.process_id,
        oc.outcome_count,
        p.company_name,
        p.job_title,
        STRING_AGG(DISTINCT o.outcome, ', ') as outcomes,
        'Process has ' || oc.outcome_count::TEXT || ' outcomes: ' || STRING_AGG(DISTINCT o.outcome, ', ') as violation_reason
    FROM outcome_counts oc
    LEFT JOIN {{ ref('int_interview_outcomes') }} o
        ON oc.process_id = o.process_id
    LEFT JOIN {{ ref('int_interview_processes') }} p
        ON oc.process_id = p.process_id
    GROUP BY oc.process_id, oc.outcome_count, p.company_name, p.job_title
)

-- This test fails if any process has multiple outcomes
SELECT * FROM duplicate_outcomes