-- Create database for Superset  
CREATE DATABASE superset;

-- Create superset user with password
CREATE USER superset WITH PASSWORD 'superset';
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;

-- Create main hirewire schema
CREATE SCHEMA IF NOT EXISTS hirewire;

-- Companies table
CREATE TABLE hirewire.companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    industry VARCHAR(100),
    size VARCHAR(50),
    location VARCHAR(255),
    website VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Job positions table
CREATE TABLE hirewire.job_positions (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES hirewire.companies(id),
    title VARCHAR(255) NOT NULL,
    department VARCHAR(100),
    level VARCHAR(50), -- junior, mid, senior, etc.
    employment_type VARCHAR(50), -- full-time, part-time, contract, etc.
    remote_policy VARCHAR(50), -- remote, hybrid, on-site
    salary_min INTEGER,
    salary_max INTEGER,
    currency VARCHAR(3) DEFAULT 'EUR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Interview processes table
CREATE TABLE hirewire.interview_processes (
    id SERIAL PRIMARY KEY,
    job_position_id INTEGER REFERENCES hirewire.job_positions(id),
    application_date DATE,
    status VARCHAR(50) NOT NULL, -- applied, screening, interviewing, offer, rejected, accepted
    source VARCHAR(100), -- linkedin, website, referral, etc.
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Individual interviews table
CREATE TABLE hirewire.interviews (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES hirewire.interview_processes(id),
    interview_type VARCHAR(50) NOT NULL, -- phone, video, on-site, technical, behavioral, etc.
    interview_round INTEGER,
    scheduled_date TIMESTAMP,
    actual_date TIMESTAMP,
    duration_minutes INTEGER,
    interviewer_name VARCHAR(255),
    interviewer_role VARCHAR(100),
    status VARCHAR(50), -- scheduled, completed, cancelled, no-show
    feedback TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    technical_topics TEXT[], -- for technical interviews
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Interview outcomes table
CREATE TABLE hirewire.interview_outcomes (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES hirewire.interview_processes(id),
    outcome VARCHAR(50) NOT NULL, -- offer, rejection, ghosted, withdrew
    outcome_date DATE,
    offer_salary INTEGER,
    offer_currency VARCHAR(3) DEFAULT 'EUR',
    rejection_reason TEXT,
    feedback_received BOOLEAN DEFAULT FALSE,
    would_reapply BOOLEAN,
    overall_experience_rating INTEGER CHECK (overall_experience_rating >= 1 AND overall_experience_rating <= 5),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_companies_name ON hirewire.companies(name);
CREATE INDEX idx_job_positions_company_id ON hirewire.job_positions(company_id);
CREATE INDEX idx_interview_processes_job_position_id ON hirewire.interview_processes(job_position_id);
CREATE INDEX idx_interview_processes_status ON hirewire.interview_processes(status);
CREATE INDEX idx_interviews_process_id ON hirewire.interviews(process_id);
CREATE INDEX idx_interviews_interview_type ON hirewire.interviews(interview_type);
CREATE INDEX idx_interview_outcomes_process_id ON hirewire.interview_outcomes(process_id);
CREATE INDEX idx_interview_outcomes_outcome ON hirewire.interview_outcomes(outcome);