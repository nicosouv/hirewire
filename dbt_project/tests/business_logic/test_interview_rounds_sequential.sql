-- Test: Interview rounds should be sequential without gaps
-- Ensures that interview rounds start at 1 and increment sequentially
-- (e.g., no process should have rounds 1, 2, 4 - missing round 3)
-- NOTE: This is a WARNING test - data quality issue but not critical

{{
  config(
    severity = 'warn'
  )
}}

WITH interview_rounds AS (
    SELECT
        i.process_id,
        i.interview_round,
        ROW_NUMBER() OVER (PARTITION BY i.process_id ORDER BY i.interview_round) as expected_round
    FROM {{ ref('int_interviews') }} i
),

round_gaps AS (
    SELECT
        process_id,
        interview_round,
        expected_round,
        'Interview round ' || interview_round::TEXT || ' found, but expected round ' || expected_round::TEXT as violation_reason
    FROM interview_rounds
    WHERE interview_round != expected_round
),

missing_round_one AS (
    SELECT
        i.process_id,
        MIN(i.interview_round) as first_round,
        'First interview round is ' || MIN(i.interview_round)::TEXT || ', expected 1' as violation_reason
    FROM {{ ref('int_interviews') }} i
    GROUP BY i.process_id
    HAVING MIN(i.interview_round) != 1
),

all_violations AS (
    SELECT
        process_id,
        violation_reason
    FROM round_gaps

    UNION ALL

    SELECT
        process_id,
        violation_reason
    FROM missing_round_one
)

-- Add process details for better debugging
SELECT
    v.process_id,
    p.company_name,
    p.job_title,
    v.violation_reason
FROM all_violations v
LEFT JOIN {{ ref('int_interview_processes') }} p
    ON v.process_id = p.process_id