-- Test: Process status should be consistent with outcome
-- If a process has an outcome, the process status should match the outcome category
-- This ensures data integrity between processes and outcomes

WITH processes_with_outcomes AS (
    SELECT
        p.process_id,
        p.process_status,
        o.outcome,
        o.outcome_category
    FROM {{ ref('int_interview_processes') }} p
    INNER JOIN {{ ref('int_interview_outcomes') }} o
        ON p.process_id = o.process_id
),

inconsistent_statuses AS (
    SELECT
        process_id,
        process_status,
        outcome,
        outcome_category,
        CASE
            -- Success outcomes should have 'accepted' or 'offer' status
            WHEN outcome_category = 'Success' AND process_status NOT IN ('accepted', 'offer') THEN 'Success outcome but status is ' || process_status
            -- Rejected outcomes should have 'rejected' status
            WHEN outcome_category = 'Rejected' AND process_status NOT IN ('rejected') THEN 'Rejected outcome but status is ' || process_status
            -- Withdrawn outcomes should have 'withdrew' status
            WHEN outcome_category = 'Withdrawn' AND process_status NOT IN ('withdrew') THEN 'Withdrawn outcome but status is ' || process_status
            -- Ghosted outcomes should have 'ghosted' status
            WHEN outcome_category = 'Ghosted' AND process_status NOT IN ('ghosted') THEN 'Ghosted outcome but status is ' || process_status
        END as inconsistency_reason
    FROM processes_with_outcomes
    WHERE
        (outcome_category = 'Success' AND process_status NOT IN ('accepted', 'offer'))
        OR (outcome_category = 'Rejected' AND process_status NOT IN ('rejected'))
        OR (outcome_category = 'Withdrawn' AND process_status NOT IN ('withdrew'))
        OR (outcome_category = 'Ghosted' AND process_status NOT IN ('ghosted'))
)

-- This test fails if there are any inconsistent records
SELECT * FROM inconsistent_statuses