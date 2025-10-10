-- Test: Salary ranges should be logically valid
-- Ensures that:
-- 1. salary_max >= salary_min when both exist
-- 2. avg_salary is between min and max when calculated
-- 3. offer_salary is reasonable (within typical range)

WITH salary_validations AS (
    SELECT
        j.position_id,
        j.company_name,
        j.job_title,
        j.salary_min,
        j.salary_max,
        j.avg_salary,
        j.currency,
        CASE
            WHEN j.salary_max IS NOT NULL AND j.salary_min IS NOT NULL AND j.salary_max < j.salary_min
                THEN 'Max salary (' || j.salary_max::TEXT || ') less than min salary (' || j.salary_min::TEXT || ')'
            WHEN j.avg_salary IS NOT NULL AND j.salary_min IS NOT NULL AND j.avg_salary < j.salary_min
                THEN 'Avg salary (' || j.avg_salary::TEXT || ') less than min salary (' || j.salary_min::TEXT || ')'
            WHEN j.avg_salary IS NOT NULL AND j.salary_max IS NOT NULL AND j.avg_salary > j.salary_max
                THEN 'Avg salary (' || j.avg_salary::TEXT || ') greater than max salary (' || j.salary_max::TEXT || ')'
            -- Check if avg_salary calculation is correct
            WHEN j.salary_min IS NOT NULL AND j.salary_max IS NOT NULL AND j.avg_salary IS NOT NULL
                 AND ABS(j.avg_salary - ((j.salary_min + j.salary_max) / 2.0)) > 0.01
                THEN 'Avg salary (' || j.avg_salary::TEXT || ') does not match calculated average (' || ((j.salary_min + j.salary_max) / 2.0)::TEXT || ')'
        END as violation_reason
    FROM {{ ref('int_job_positions') }} j
    WHERE
        j.salary_min IS NOT NULL OR j.salary_max IS NOT NULL OR j.avg_salary IS NOT NULL
),

offer_validations AS (
    SELECT
        o.outcome_id,
        o.process_id,
        o.offer_salary,
        o.offer_currency,
        'Offer salary is negative or zero: ' || o.offer_salary::TEXT as violation_reason
    FROM {{ ref('int_interview_outcomes') }} o
    WHERE
        o.offer_salary IS NOT NULL
        AND o.offer_salary <= 0
),

all_violations AS (
    SELECT
        position_id::TEXT as record_id,
        'job_position' as record_type,
        company_name || ' - ' || job_title as record_description,
        violation_reason
    FROM salary_validations
    WHERE violation_reason IS NOT NULL

    UNION ALL

    SELECT
        outcome_id::TEXT as record_id,
        'outcome' as record_type,
        'Process ID: ' || process_id::TEXT as record_description,
        violation_reason
    FROM offer_validations
)

-- This test fails if any salary violations exist
SELECT * FROM all_violations