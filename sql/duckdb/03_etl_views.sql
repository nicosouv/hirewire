-- ETL Views for transforming PostgreSQL raw data to DuckDB star schema
-- These views help with the data transformation process

-- =======================
-- HELPER VIEWS
-- =======================

-- View to get the latest company dimension records
CREATE OR REPLACE VIEW v_latest_companies AS
SELECT 
    company_key,
    company_id,
    company_name,
    industry,
    company_size,
    location,
    website
FROM dim_companies 
WHERE is_current = TRUE;

-- View to get the latest job position dimension records
CREATE OR REPLACE VIEW v_latest_positions AS
SELECT 
    position_key,
    position_id,
    job_title,
    department,
    job_level,
    employment_type,
    remote_policy,
    salary_min,
    salary_max,
    currency
FROM dim_job_positions 
WHERE is_current = TRUE;

-- =======================
-- ETL TRANSFORMATION VIEWS
-- =======================

-- View for companies ETL (from PostgreSQL to DuckDB dimensions)
CREATE OR REPLACE VIEW v_etl_companies AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY id) + (SELECT COALESCE(MAX(company_key), 0) FROM dim_companies) as company_key,
    id as company_id,
    name as company_name,
    industry,
    size as company_size,
    location,
    website,
    created_at::DATE as effective_date,
    NULL as expiry_date,
    TRUE as is_current,
    created_at
FROM postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.companies') 
WHERE id NOT IN (SELECT DISTINCT company_id FROM dim_companies WHERE is_current = TRUE);

-- View for job positions ETL
CREATE OR REPLACE VIEW v_etl_job_positions AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY id) + (SELECT COALESCE(MAX(position_key), 0) FROM dim_job_positions) as position_key,
    id as position_id,
    title as job_title,
    department,
    level as job_level,
    employment_type,
    remote_policy,
    salary_min,
    salary_max,
    currency,
    created_at::DATE as effective_date,
    NULL as expiry_date,
    TRUE as is_current,
    created_at
FROM postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.job_positions')
WHERE id NOT IN (SELECT DISTINCT position_id FROM dim_job_positions WHERE is_current = TRUE);

-- View for interviewers ETL
CREATE OR REPLACE VIEW v_etl_interviewers AS
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY interviewer_name, interviewer_role) + (SELECT COALESCE(MAX(interviewer_key), 0) FROM dim_interviewers) as interviewer_key,
    interviewer_name,
    interviewer_role,
    NULL as company_key, -- To be updated based on the interview process
    created_at::DATE as effective_date,
    NULL as expiry_date,
    TRUE as is_current
FROM postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT DISTINCT interviewer_name, interviewer_role, created_at FROM hirewire.interviews WHERE interviewer_name IS NOT NULL')
WHERE interviewer_name NOT IN (SELECT DISTINCT interviewer_name FROM dim_interviewers WHERE is_current = TRUE);

-- =======================
-- FACT TABLE ETL VIEWS
-- =======================

-- View for interview processes fact table ETL
CREATE OR REPLACE VIEW v_etl_fact_processes AS
WITH process_data AS (
    SELECT 
        ip.id as process_id,
        ip.job_position_id,
        jp.company_id,
        ip.application_date,
        ip.status,
        ip.source,
        io.outcome,
        io.outcome_date,
        io.offer_salary,
        io.offer_currency,
        io.overall_experience_rating,
        io.feedback_received,
        io.would_reapply,
        CASE WHEN io.outcome = 'ghosted' THEN TRUE ELSE FALSE END as was_ghosted,
        CASE 
            WHEN io.outcome_date IS NOT NULL AND ip.application_date IS NOT NULL 
            THEN (io.outcome_date - ip.application_date) 
            ELSE NULL 
        END as process_duration_days,
        COUNT(i.id) as total_interviews,
        SUM(i.duration_minutes) as total_interview_duration_minutes
    FROM postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.interview_processes') ip
    LEFT JOIN postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.job_positions') jp ON ip.job_position_id = jp.id
    LEFT JOIN postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.interview_outcomes') io ON ip.id = io.process_id
    LEFT JOIN postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.interviews') i ON ip.id = i.process_id
    GROUP BY ip.id, ip.job_position_id, jp.company_id, ip.application_date, ip.status, ip.source,
             io.outcome, io.outcome_date, io.offer_salary, io.offer_currency, io.overall_experience_rating,
             io.feedback_received, io.would_reapply
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY process_id) + (SELECT COALESCE(MAX(process_fact_key), 0) FROM fact_interview_processes) as process_fact_key,
    pd.process_id,
    dc.company_key,
    dp.position_key,
    dd_app.date_key as application_date_key,
    dd_out.date_key as outcome_date_key,
    das.source_key,
    dps.status_key as final_status_key,
    pd.total_interviews,
    pd.total_interview_duration_minutes,
    pd.process_duration_days,
    pd.offer_salary,
    pd.offer_currency,
    pd.overall_experience_rating,
    pd.feedback_received,
    pd.would_reapply,
    pd.was_ghosted,
    CURRENT_TIMESTAMP as created_at,
    CURRENT_TIMESTAMP as updated_at
FROM process_data pd
LEFT JOIN v_latest_companies dc ON pd.company_id = dc.company_id
LEFT JOIN v_latest_positions dp ON pd.job_position_id = dp.position_id
LEFT JOIN dim_date dd_app ON CAST(strftime('%Y%m%d', pd.application_date) AS INTEGER) = dd_app.date_key
LEFT JOIN dim_date dd_out ON CAST(strftime('%Y%m%d', pd.outcome_date) AS INTEGER) = dd_out.date_key
LEFT JOIN dim_application_sources das ON LOWER(pd.source) = LOWER(das.source_name)
LEFT JOIN dim_process_status dps ON COALESCE(pd.outcome, pd.status) = dps.status_name
WHERE pd.process_id NOT IN (SELECT DISTINCT process_id FROM fact_interview_processes);

-- View for individual interviews fact table ETL
CREATE OR REPLACE VIEW v_etl_fact_interviews AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY i.id) + (SELECT COALESCE(MAX(interview_fact_key), 0) FROM fact_interviews) as interview_fact_key,
    i.id as interview_id,
    fp.process_fact_key,
    dc.company_key,
    dp.position_key,
    dit.interview_type_key,
    dd_sched.date_key as scheduled_date_key,
    dd_actual.date_key as actual_date_key,
    di.interviewer_key,
    i.interview_round,
    i.duration_minutes,
    i.rating,
    NULL as preparation_time_hours, -- Not in source schema yet
    i.technical_topics,
    CASE WHEN ARRAY_LENGTH(i.technical_topics) > 0 THEN TRUE ELSE FALSE END as coding_challenge,
    CASE WHEN i.interview_type = 'system_design' THEN TRUE ELSE FALSE END as system_design,
    i.status as interview_status,
    CASE WHEN i.actual_date IS NOT NULL AND i.scheduled_date IS NOT NULL 
         AND i.actual_date <= i.scheduled_date + INTERVAL '15 minutes' 
         THEN TRUE ELSE FALSE END as was_on_time,
    NULL as technical_difficulty, -- Not in source schema yet
    i.created_at
FROM postgres_read('host=postgres user=postgres password=password dbname=hirewire', 'SELECT * FROM hirewire.interviews') i
LEFT JOIN fact_interview_processes fp ON i.process_id = fp.process_id
LEFT JOIN v_latest_companies dc ON fp.company_key = dc.company_key
LEFT JOIN v_latest_positions dp ON fp.position_key = dp.position_key
LEFT JOIN dim_interview_types dit ON i.interview_type = dit.interview_type
LEFT JOIN dim_date dd_sched ON CAST(strftime('%Y%m%d', i.scheduled_date) AS INTEGER) = dd_sched.date_key
LEFT JOIN dim_date dd_actual ON CAST(strftime('%Y%m%d', i.actual_date) AS INTEGER) = dd_actual.date_key
LEFT JOIN dim_interviewers di ON i.interviewer_name = di.interviewer_name AND di.is_current = TRUE
WHERE i.id NOT IN (SELECT DISTINCT interview_id FROM fact_interviews);