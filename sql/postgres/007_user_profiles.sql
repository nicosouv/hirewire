-- User Profile & Settings Schema
-- RGPD-compliant user profile for AI Interview Prep and personalization

-- User profile table (extends users table)
CREATE TABLE IF NOT EXISTS hirewire.user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES hirewire.users(id) ON DELETE CASCADE,

    -- Professional info (for AI Interview Prep)
    current_job_title VARCHAR(255),
    target_job_title VARCHAR(255), -- What they're applying for
    years_of_experience INTEGER CHECK (years_of_experience >= 0 AND years_of_experience <= 50),
    industries TEXT[], -- Array of industries (e.g., ARRAY['Tech', 'Finance'])

    -- Skills & Education
    skills TEXT[], -- Array of skills (e.g., ARRAY['Python', 'React', 'SQL'])
    education_level VARCHAR(100), -- 'Bachelor', 'Master', 'PhD', 'Bootcamp', 'Self-taught'
    certifications TEXT[], -- Array of certifications
    languages JSONB, -- [{"language": "English", "proficiency": "fluent"}, ...]

    -- Work preferences
    work_authorization VARCHAR(100), -- 'US Citizen', 'Green Card', 'H1B', 'EU Work Permit'
    location_preferences JSONB, -- {"remote": true, "hybrid": true, "onsite": false, "cities": ["San Francisco", "New York"]}

    -- Salary (opt-in only)
    salary_expectations_min INTEGER CHECK (salary_expectations_min >= 0),
    salary_expectations_max INTEGER CHECK (salary_expectations_max >= 0),
    current_salary INTEGER CHECK (current_salary >= 0),

    -- AI preferences
    preferred_interview_language VARCHAR(50) DEFAULT 'English',
    ai_interview_prep_enabled BOOLEAN DEFAULT TRUE,

    -- Privacy settings
    profile_visibility VARCHAR(50) DEFAULT 'private' CHECK (profile_visibility IN ('private', 'public')),
    data_processing_consent BOOLEAN DEFAULT FALSE, -- RGPD: explicit consent for AI processing
    data_processing_consent_date TIMESTAMP,

    -- Resume/CV (optional)
    resume_file_url TEXT, -- S3 URL to uploaded resume
    resume_uploaded_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_user ON hirewire.user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_consent ON hirewire.user_profiles(data_processing_consent);

-- RGPD Compliance: Data export log
CREATE TABLE IF NOT EXISTS hirewire.data_export_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,
    request_type VARCHAR(50) NOT NULL CHECK (request_type IN ('export', 'delete')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    export_file_url TEXT, -- S3 URL to exported data (JSON)
    requested_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_data_export_requests_user ON hirewire.data_export_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_data_export_requests_status ON hirewire.data_export_requests(status);

-- RGPD Compliance: Audit log for profile changes
CREATE TABLE IF NOT EXISTS hirewire.profile_audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,
    field_changed VARCHAR(255) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_audit_log_user ON hirewire.profile_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_audit_log_date ON hirewire.profile_audit_log(changed_at);

-- Comments
COMMENT ON TABLE hirewire.user_profiles IS 'User professional profiles for AI personalization (RGPD-compliant)';
COMMENT ON COLUMN hirewire.user_profiles.data_processing_consent IS 'Explicit consent for AI processing of profile data';
COMMENT ON COLUMN hirewire.user_profiles.salary_expectations_min IS 'Minimum salary expectation in USD (encrypted in app)';
COMMENT ON TABLE hirewire.data_export_requests IS 'RGPD compliance: track data export and deletion requests';
COMMENT ON TABLE hirewire.profile_audit_log IS 'RGPD compliance: audit trail for sensitive profile changes';
