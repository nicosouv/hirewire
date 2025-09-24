-- CONSTRAINTS TO PREVENT DATA INCONSISTENCIES
-- Add after basic schema is created

-- ===========================================
-- 1. BUSINESS LOGIC CONSTRAINTS
-- ===========================================

-- Prevent multiple active processes for same position
-- A position can only have ONE process without outcome at a time
CREATE OR REPLACE FUNCTION check_single_active_process()
RETURNS TRIGGER AS $$
BEGIN
    -- Only check for INSERT and UPDATE that might create conflicts
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Check if there's already an active process for this position
        IF EXISTS (
            SELECT 1
            FROM hirewire.interview_processes ip
            LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
            WHERE ip.job_position_id = NEW.job_position_id
              AND ip.id != NEW.id  -- Exclude current record for updates
              AND io.process_id IS NULL  -- No outcome = active process
        ) THEN
            RAISE EXCEPTION 'Cannot create multiple active processes for position %. Complete existing process first.', NEW.job_position_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to interview_processes table
CREATE TRIGGER ensure_single_active_process
    BEFORE INSERT OR UPDATE ON hirewire.interview_processes
    FOR EACH ROW EXECUTE FUNCTION check_single_active_process();

-- ===========================================
-- 2. DATA INTEGRITY CONSTRAINTS
-- ===========================================

-- Ensure outcome dates are logical
ALTER TABLE hirewire.interview_outcomes
ADD CONSTRAINT check_outcome_date_logical
CHECK (outcome_date >= '2020-01-01' AND outcome_date <= CURRENT_DATE + INTERVAL '1 year');

-- Ensure interview dates are logical
ALTER TABLE hirewire.interviews
ADD CONSTRAINT check_interview_dates_logical
CHECK (
    scheduled_date >= '2020-01-01'
    AND scheduled_date <= CURRENT_DATE + INTERVAL '1 year'
    AND (actual_date IS NULL OR actual_date >= '2020-01-01')
);

-- Ensure application dates are logical
ALTER TABLE hirewire.interview_processes
ADD CONSTRAINT check_application_date_logical
CHECK (application_date >= '2020-01-01' AND application_date <= CURRENT_DATE + INTERVAL '1 month');

-- Ensure ratings are in valid range
ALTER TABLE hirewire.interviews
ADD CONSTRAINT check_rating_range
CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5));

ALTER TABLE hirewire.interview_outcomes
ADD CONSTRAINT check_experience_rating_range
CHECK (overall_experience_rating IS NULL OR (overall_experience_rating >= 1 AND overall_experience_rating <= 5));

-- ===========================================
-- 3. ENUM-LIKE CONSTRAINTS
-- ===========================================

-- Valid interview process statuses
ALTER TABLE hirewire.interview_processes
ADD CONSTRAINT check_valid_process_status
CHECK (status IN (
    'applied', 'screening', 'interviewing', 'tech_test', 'final_round',
    'offer', 'rejected', 'accepted', 'withdrew', 'ghosted', 'reminder'
));

-- Valid interview statuses
ALTER TABLE hirewire.interviews
ADD CONSTRAINT check_valid_interview_status
CHECK (status IN ('scheduled', 'completed', 'cancelled', 'no_show', 'rescheduled'));

-- Valid outcomes
ALTER TABLE hirewire.interview_outcomes
ADD CONSTRAINT check_valid_outcome
CHECK (outcome IN ('offer', 'rejection', 'accepted', 'ghosted', 'withdrew'));

-- Valid sources
ALTER TABLE hirewire.interview_processes
ADD CONSTRAINT check_valid_source
CHECK (source IN (
    'linkedin', 'indeed', 'company_website', 'referral_internal',
    'referral_external', 'networking', 'recruiter', 'other',
    'france_travail', 'wttj'
));

-- ===========================================
-- 4. LOGICAL CONSISTENCY CONSTRAINTS
-- ===========================================

-- Ensure salary ranges make sense
ALTER TABLE hirewire.job_positions
ADD CONSTRAINT check_salary_range_logical
CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max);

-- Ensure interview rounds are positive
ALTER TABLE hirewire.interviews
ADD CONSTRAINT check_interview_round_positive
CHECK (interview_round IS NULL OR interview_round > 0);

-- Ensure duration is reasonable (5 minutes to 8 hours)
ALTER TABLE hirewire.interviews
ADD CONSTRAINT check_duration_reasonable
CHECK (duration_minutes IS NULL OR (duration_minutes >= 5 AND duration_minutes <= 480));

-- ===========================================
-- 5. CROSS-TABLE CONSISTENCY FUNCTION
-- ===========================================

-- Function to check that process status matches outcome
CREATE OR REPLACE FUNCTION check_process_outcome_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- When adding/updating an outcome, check process status consistency
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Update process status to match outcome if they don't align
        UPDATE hirewire.interview_processes
        SET status = CASE
            WHEN NEW.outcome = 'offer' THEN 'offer'
            WHEN NEW.outcome = 'accepted' THEN 'accepted'
            WHEN NEW.outcome = 'rejection' THEN 'rejected'
            WHEN NEW.outcome = 'ghosted' THEN 'ghosted'
            WHEN NEW.outcome = 'withdrew' THEN 'withdrew'
            ELSE status
        END
        WHERE id = NEW.process_id
          AND status != CASE
              WHEN NEW.outcome = 'offer' THEN 'offer'
              WHEN NEW.outcome = 'accepted' THEN 'accepted'
              WHEN NEW.outcome = 'rejection' THEN 'rejected'
              WHEN NEW.outcome = 'ghosted' THEN 'ghosted'
              WHEN NEW.outcome = 'withdrew' THEN 'withdrew'
              ELSE status
          END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to interview_outcomes table
CREATE TRIGGER ensure_process_outcome_consistency
    AFTER INSERT OR UPDATE ON hirewire.interview_outcomes
    FOR EACH ROW EXECUTE FUNCTION check_process_outcome_consistency();

-- ===========================================
-- 6. USEFUL INDEXES FOR CONSTRAINTS
-- ===========================================

-- Index to speed up active process checks
CREATE INDEX idx_active_processes ON hirewire.interview_processes(job_position_id)
WHERE job_position_id IN (
    SELECT ip.job_position_id
    FROM hirewire.interview_processes ip
    LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
    WHERE io.process_id IS NULL
);

-- Partial index for outcome consistency checks
CREATE INDEX idx_process_outcomes ON hirewire.interview_outcomes(process_id, outcome);

-- ===========================================
-- 7. VALIDATION QUERIES
-- ===========================================

-- Query to find violations (run after adding constraints)
-- Multiple active processes (should return 0 rows)
SELECT
    jp.id as position_id,
    c.name as company,
    jp.title,
    COUNT(ip.id) as active_processes
FROM hirewire.job_positions jp
JOIN hirewire.companies c ON jp.company_id = c.id
JOIN hirewire.interview_processes ip ON jp.id = ip.job_position_id
LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
WHERE io.process_id IS NULL
GROUP BY jp.id, c.name, jp.title
HAVING COUNT(ip.id) > 1;

-- Process/outcome status mismatches (should return 0 rows)
SELECT
    ip.id,
    ip.status as process_status,
    io.outcome
FROM hirewire.interview_processes ip
JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
WHERE (
    (io.outcome = 'accepted' AND ip.status != 'accepted') OR
    (io.outcome = 'rejected' AND ip.status != 'rejected') OR
    (io.outcome = 'offer' AND ip.status != 'offer') OR
    (io.outcome = 'ghosted' AND ip.status != 'ghosted') OR
    (io.outcome = 'withdrew' AND ip.status != 'withdrew')
);