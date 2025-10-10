-- Create users table
CREATE TABLE IF NOT EXISTS hirewire.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_superuser BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add user_id to interview_processes
ALTER TABLE hirewire.interview_processes
ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES hirewire.users(id) ON DELETE CASCADE;

-- Create index on user_id for better query performance
CREATE INDEX IF NOT EXISTS idx_interview_processes_user_id ON hirewire.interview_processes(user_id);

-- Create a default user (password: "password123" - bcrypt hash)
INSERT INTO hirewire.users (email, hashed_password, first_name, last_name, is_superuser)
VALUES (
    'admin@hirewire.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYjLPjy5xu2',
    'Admin',
    'User',
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- Assign all existing processes to the default user
UPDATE hirewire.interview_processes
SET user_id = (SELECT id FROM hirewire.users WHERE email = 'admin@hirewire.com')
WHERE user_id IS NULL;

-- Make user_id NOT NULL after assigning
ALTER TABLE hirewire.interview_processes
ALTER COLUMN user_id SET NOT NULL;

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION hirewire.update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_users_timestamp
    BEFORE UPDATE ON hirewire.users
    FOR EACH ROW
    EXECUTE FUNCTION hirewire.update_users_updated_at();

-- Comments
COMMENT ON TABLE hirewire.users IS 'User accounts for the HireWire application';
COMMENT ON COLUMN hirewire.users.email IS 'Unique email address for login';
COMMENT ON COLUMN hirewire.users.hashed_password IS 'Bcrypt hashed password';
COMMENT ON COLUMN hirewire.users.is_active IS 'Whether the user account is active';
COMMENT ON COLUMN hirewire.users.is_superuser IS 'Whether the user has admin privileges';
