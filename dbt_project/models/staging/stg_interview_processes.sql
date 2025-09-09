{{ config(materialized='table') }}

SELECT
    id,
    job_position_id,
    application_date,
    status,
    source,
    notes,
    created_at,
    updated_at
FROM {{ postgres_scan('interview_processes') }}