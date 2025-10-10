-- Test: Data recency and update timestamp validation
-- Ensures that records are being updated and created_at/updated_at are logical

{{
  config(
    severity = 'warn'
  )
}}

WITH timestamp_validations AS (
    -- Check staging layer timestamps
    SELECT
        'stg_companies' as table_name,
        id as record_id,
        created_at,
        updated_at,
        CASE
            WHEN updated_at < created_at
                THEN 'Updated timestamp before created timestamp'
            WHEN created_at > CURRENT_TIMESTAMP
                THEN 'Created timestamp in the future'
            WHEN updated_at > CURRENT_TIMESTAMP
                THEN 'Updated timestamp in the future'
        END as violation_reason
    FROM {{ ref('stg_companies') }}
    WHERE
        updated_at < created_at
        OR created_at > CURRENT_TIMESTAMP
        OR updated_at > CURRENT_TIMESTAMP

    UNION ALL

    SELECT
        'stg_job_positions' as table_name,
        id as record_id,
        created_at,
        updated_at,
        CASE
            WHEN updated_at < created_at
                THEN 'Updated timestamp before created timestamp'
            WHEN created_at > CURRENT_TIMESTAMP
                THEN 'Created timestamp in the future'
            WHEN updated_at > CURRENT_TIMESTAMP
                THEN 'Updated timestamp in the future'
        END as violation_reason
    FROM {{ ref('stg_job_positions') }}
    WHERE
        updated_at < created_at
        OR created_at > CURRENT_TIMESTAMP
        OR updated_at > CURRENT_TIMESTAMP

    UNION ALL

    SELECT
        'stg_interview_processes' as table_name,
        id as record_id,
        created_at,
        updated_at,
        CASE
            WHEN updated_at < created_at
                THEN 'Updated timestamp before created timestamp'
            WHEN created_at > CURRENT_TIMESTAMP
                THEN 'Created timestamp in the future'
            WHEN updated_at > CURRENT_TIMESTAMP
                THEN 'Updated timestamp in the future'
        END as violation_reason
    FROM {{ ref('stg_interview_processes') }}
    WHERE
        updated_at < created_at
        OR created_at > CURRENT_TIMESTAMP
        OR updated_at > CURRENT_TIMESTAMP

    UNION ALL

    SELECT
        'stg_interviews' as table_name,
        id as record_id,
        created_at,
        updated_at,
        CASE
            WHEN updated_at < created_at
                THEN 'Updated timestamp before created timestamp'
            WHEN created_at > CURRENT_TIMESTAMP
                THEN 'Created timestamp in the future'
            WHEN updated_at > CURRENT_TIMESTAMP
                THEN 'Updated timestamp in the future'
        END as violation_reason
    FROM {{ ref('stg_interviews') }}
    WHERE
        updated_at < created_at
        OR created_at > CURRENT_TIMESTAMP
        OR updated_at > CURRENT_TIMESTAMP

    UNION ALL

    SELECT
        'stg_interview_outcomes' as table_name,
        id as record_id,
        created_at,
        updated_at,
        CASE
            WHEN updated_at < created_at
                THEN 'Updated timestamp before created timestamp'
            WHEN created_at > CURRENT_TIMESTAMP
                THEN 'Created timestamp in the future'
            WHEN updated_at > CURRENT_TIMESTAMP
                THEN 'Updated timestamp in the future'
        END as violation_reason
    FROM {{ ref('stg_interview_outcomes') }}
    WHERE
        updated_at < created_at
        OR created_at > CURRENT_TIMESTAMP
        OR updated_at > CURRENT_TIMESTAMP
)

-- This test fails if any timestamp violations exist
SELECT * FROM timestamp_validations