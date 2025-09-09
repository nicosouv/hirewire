-- HireWire Data Warehouse - Star Schema
-- DuckDB implementation

-- =======================
-- DIMENSION TABLES
-- =======================

-- Dimension: Companies
CREATE TABLE IF NOT EXISTS dim_companies (
    company_key INTEGER PRIMARY KEY,
    company_id INTEGER NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    industry VARCHAR(100),
    company_size VARCHAR(50),
    location VARCHAR(255),
    website VARCHAR(255),
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dimension: Job Positions
CREATE TABLE IF NOT EXISTS dim_job_positions (
    position_key INTEGER PRIMARY KEY,
    position_id INTEGER NOT NULL,
    job_title VARCHAR(255) NOT NULL,
    department VARCHAR(100),
    job_level VARCHAR(50), -- junior, mid, senior, etc.
    employment_type VARCHAR(50), -- full-time, part-time, contract
    remote_policy VARCHAR(50), -- remote, hybrid, on-site
    salary_min INTEGER,
    salary_max INTEGER,
    currency VARCHAR(3) DEFAULT 'EUR',
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dimension: Time (for date analysis)
CREATE TABLE IF NOT EXISTS dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    week INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE
);

-- Dimension: Interview Types
CREATE TABLE IF NOT EXISTS dim_interview_types (
    interview_type_key INTEGER PRIMARY KEY,
    interview_type VARCHAR(50) NOT NULL,
    interview_category VARCHAR(50), -- technical, behavioral, cultural, screening
    typical_duration_minutes INTEGER,
    description TEXT
);

-- Dimension: Application Sources
CREATE TABLE IF NOT EXISTS dim_application_sources (
    source_key INTEGER PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL,
    source_category VARCHAR(50), -- job_board, referral, direct, recruiter
    description TEXT
);

-- Dimension: Process Status
CREATE TABLE IF NOT EXISTS dim_process_status (
    status_key INTEGER PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL,
    status_category VARCHAR(50), -- active, completed, cancelled
    status_order INTEGER, -- for sorting
    description TEXT
);

-- Dimension: Interviewers
CREATE TABLE IF NOT EXISTS dim_interviewers (
    interviewer_key INTEGER PRIMARY KEY,
    interviewer_name VARCHAR(255) NOT NULL,
    interviewer_role VARCHAR(100),
    company_key INTEGER,
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE
);

-- =======================
-- FACT TABLES
-- =======================

-- Fact: Interview Processes (One record per application)
CREATE TABLE IF NOT EXISTS fact_interview_processes (
    process_fact_key INTEGER PRIMARY KEY,
    process_id INTEGER NOT NULL,
    
    -- Foreign Keys to Dimensions
    company_key INTEGER NOT NULL,
    position_key INTEGER NOT NULL,
    application_date_key INTEGER NOT NULL,
    outcome_date_key INTEGER,
    source_key INTEGER NOT NULL,
    final_status_key INTEGER NOT NULL,
    
    -- Measures
    total_interviews INTEGER DEFAULT 0,
    total_interview_duration_minutes INTEGER DEFAULT 0,
    process_duration_days INTEGER,
    offer_salary INTEGER,
    offer_currency VARCHAR(3),
    overall_experience_rating INTEGER CHECK (overall_experience_rating >= 1 AND overall_experience_rating <= 5),
    
    -- Flags
    received_feedback BOOLEAN DEFAULT FALSE,
    would_reapply BOOLEAN,
    was_ghosted BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (company_key) REFERENCES dim_companies(company_key),
    FOREIGN KEY (position_key) REFERENCES dim_job_positions(position_key),
    FOREIGN KEY (application_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (outcome_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (source_key) REFERENCES dim_application_sources(source_key),
    FOREIGN KEY (final_status_key) REFERENCES dim_process_status(status_key)
);

-- Fact: Individual Interviews (One record per interview)
CREATE TABLE IF NOT EXISTS fact_interviews (
    interview_fact_key INTEGER PRIMARY KEY,
    interview_id INTEGER NOT NULL,
    process_fact_key INTEGER NOT NULL,
    
    -- Foreign Keys to Dimensions
    company_key INTEGER NOT NULL,
    position_key INTEGER NOT NULL,
    interview_type_key INTEGER NOT NULL,
    scheduled_date_key INTEGER,
    actual_date_key INTEGER,
    interviewer_key INTEGER,
    
    -- Measures
    interview_round INTEGER,
    duration_minutes INTEGER,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    preparation_time_hours INTEGER,
    
    -- Technical interview specific
    technical_topics TEXT[],
    coding_challenge BOOLEAN DEFAULT FALSE,
    system_design BOOLEAN DEFAULT FALSE,
    
    -- Status and flags
    interview_status VARCHAR(50), -- scheduled, completed, cancelled, no-show
    was_on_time BOOLEAN,
    technical_difficulty INTEGER CHECK (technical_difficulty >= 1 AND technical_difficulty <= 5),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (process_fact_key) REFERENCES fact_interview_processes(process_fact_key),
    FOREIGN KEY (company_key) REFERENCES dim_companies(company_key),
    FOREIGN KEY (position_key) REFERENCES dim_job_positions(position_key),
    FOREIGN KEY (interview_type_key) REFERENCES dim_interview_types(interview_type_key),
    FOREIGN KEY (scheduled_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (actual_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (interviewer_key) REFERENCES dim_interviewers(interviewer_key)
);

-- =======================
-- INDEXES FOR PERFORMANCE
-- =======================

-- Dimension table indexes
CREATE INDEX idx_dim_companies_current ON dim_companies(is_current);
CREATE INDEX idx_dim_companies_industry ON dim_companies(industry);
CREATE INDEX idx_dim_job_positions_current ON dim_job_positions(is_current);
CREATE INDEX idx_dim_job_positions_level ON dim_job_positions(job_level);
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);
CREATE INDEX idx_dim_date_quarter ON dim_date(year, quarter);

-- Fact table indexes
CREATE INDEX idx_fact_processes_company ON fact_interview_processes(company_key);
CREATE INDEX idx_fact_processes_position ON fact_interview_processes(position_key);
CREATE INDEX idx_fact_processes_app_date ON fact_interview_processes(application_date_key);
CREATE INDEX idx_fact_processes_status ON fact_interview_processes(final_status_key);

CREATE INDEX idx_fact_interviews_process ON fact_interviews(process_fact_key);
CREATE INDEX idx_fact_interviews_company ON fact_interviews(company_key);
CREATE INDEX idx_fact_interviews_type ON fact_interviews(interview_type_key);
CREATE INDEX idx_fact_interviews_date ON fact_interviews(actual_date_key);