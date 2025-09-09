-- Populate dimension tables with reference data
-- Run this after creating the star schema

-- =======================
-- POPULATE DIM_DATE
-- =======================

-- Generate date dimension for 5 years (2020-2027)
INSERT INTO dim_date (
    date_key, full_date, year, quarter, month, month_name, week, 
    day_of_year, day_of_month, day_of_week, day_name, is_weekend
)
SELECT 
    CAST(strftime('%Y%m%d', d.date_val) AS INTEGER) as date_key,
    d.date_val as full_date,
    EXTRACT(year FROM d.date_val) as year,
    EXTRACT(quarter FROM d.date_val) as quarter,
    EXTRACT(month FROM d.date_val) as month,
    strftime('%B', d.date_val) as month_name,
    EXTRACT(week FROM d.date_val) as week,
    EXTRACT(dayofyear FROM d.date_val) as day_of_year,
    EXTRACT(day FROM d.date_val) as day_of_month,
    EXTRACT(dayofweek FROM d.date_val) as day_of_week,
    strftime('%A', d.date_val) as day_name,
    CASE WHEN EXTRACT(dayofweek FROM d.date_val) IN (0, 6) THEN TRUE ELSE FALSE END as is_weekend
FROM (
    SELECT DATE '2020-01-01' + INTERVAL (seq) DAY as date_val
    FROM generate_series(0, 2922) as t(seq) -- 8 years * 365.25 days
) d;

-- =======================
-- POPULATE DIM_INTERVIEW_TYPES
-- =======================

INSERT INTO dim_interview_types (interview_type_key, interview_type, interview_category, typical_duration_minutes, description) VALUES
(1, 'phone_screening', 'screening', 30, 'Initial phone screening with HR or recruiter'),
(2, 'video_screening', 'screening', 30, 'Video call screening with HR or recruiter'),
(3, 'technical_phone', 'technical', 60, 'Technical phone interview'),
(4, 'technical_video', 'technical', 90, 'Technical video interview with coding'),
(5, 'coding_challenge', 'technical', 120, 'Live coding challenge'),
(6, 'system_design', 'technical', 90, 'System design interview'),
(7, 'behavioral', 'behavioral', 60, 'Behavioral interview focusing on past experiences'),
(8, 'cultural_fit', 'cultural', 45, 'Cultural fit and values alignment interview'),
(9, 'final_round', 'behavioral', 60, 'Final interview round, usually with senior management'),
(10, 'on_site', 'mixed', 240, 'Full day on-site interview'),
(11, 'presentation', 'technical', 90, 'Presentation or case study interview'),
(12, 'pair_programming', 'technical', 120, 'Pair programming session'),
(13, 'take_home', 'technical', 0, 'Take-home coding assignment');

-- =======================
-- POPULATE DIM_APPLICATION_SOURCES
-- =======================

INSERT INTO dim_application_sources (source_key, source_name, source_category, description) VALUES
(1, 'linkedin', 'job_board', 'LinkedIn job postings'),
(2, 'indeed', 'job_board', 'Indeed job postings'),
(3, 'glassdoor', 'job_board', 'Glassdoor job postings'),
(4, 'company_website', 'direct', 'Direct application through company website'),
(5, 'referral_internal', 'referral', 'Internal employee referral'),
(6, 'referral_external', 'referral', 'External professional referral'),
(7, 'recruiter_agency', 'recruiter', 'External recruiting agency'),
(8, 'recruiter_internal', 'recruiter', 'Internal company recruiter'),
(9, 'job_fair', 'event', 'Job fair or career event'),
(10, 'networking', 'networking', 'Professional networking'),
(11, 'cold_outreach', 'direct', 'Cold email or LinkedIn message'),
(12, 'stackoverflow', 'job_board', 'Stack Overflow Jobs'),
(13, 'angel_list', 'job_board', 'AngelList (Wellfound)'),
(14, 'ycombinator', 'job_board', 'Y Combinator Work List'),
(15, 'other', 'other', 'Other sources not listed');

-- =======================
-- POPULATE DIM_PROCESS_STATUS
-- =======================

INSERT INTO dim_process_status (status_key, status_name, status_category, status_order, description) VALUES
(1, 'applied', 'active', 1, 'Application submitted'),
(2, 'screening', 'active', 2, 'Initial screening phase'),
(3, 'interviewing', 'active', 3, 'In interview process'),
(4, 'final_round', 'active', 4, 'Final interview round'),
(5, 'offer', 'completed', 5, 'Offer received'),
(6, 'accepted', 'completed', 6, 'Offer accepted'),
(7, 'rejected', 'completed', 7, 'Application rejected'),
(8, 'withdrew', 'cancelled', 8, 'Candidate withdrew'),
(9, 'ghosted', 'cancelled', 9, 'No response from company'),
(10, 'on_hold', 'active', 10, 'Process on hold');

-- =======================
-- CREATE SEQUENCES FOR PRIMARY KEYS
-- =======================

CREATE SEQUENCE seq_company_key START 1;
CREATE SEQUENCE seq_position_key START 1;
CREATE SEQUENCE seq_interviewer_key START 1;
CREATE SEQUENCE seq_process_fact_key START 1;
CREATE SEQUENCE seq_interview_fact_key START 1;