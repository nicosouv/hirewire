-- Create exports table for tracking export requests
CREATE TABLE IF NOT EXISTS hirewire.exports (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,

    -- Export parameters
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    format VARCHAR(10) NOT NULL CHECK (format IN ('excel', 'csv')),
    recipient_email VARCHAR(255) NOT NULL,

    -- Tracking
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    airflow_dag_run_id VARCHAR(255),
    file_path TEXT,
    error_message TEXT,

    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_exports_user_id ON hirewire.exports(user_id);
CREATE INDEX idx_exports_status ON hirewire.exports(status);
CREATE INDEX idx_exports_created_at ON hirewire.exports(created_at DESC);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_exports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_exports_updated_at
BEFORE UPDATE ON hirewire.exports
FOR EACH ROW
EXECUTE FUNCTION update_exports_updated_at();

-- Add comments for documentation
COMMENT ON TABLE hirewire.exports IS 'Tracks user export requests and their processing status';
COMMENT ON COLUMN hirewire.exports.user_id IS 'User who requested the export';
COMMENT ON COLUMN hirewire.exports.start_date IS 'Start date for export data range';
COMMENT ON COLUMN hirewire.exports.end_date IS 'End date for export data range';
COMMENT ON COLUMN hirewire.exports.format IS 'Export format: excel or csv';
COMMENT ON COLUMN hirewire.exports.recipient_email IS 'Email address to send the export to';
COMMENT ON COLUMN hirewire.exports.status IS 'Current status: pending, processing, completed, or failed';
COMMENT ON COLUMN hirewire.exports.airflow_dag_run_id IS 'Airflow DAG run ID for tracking';
COMMENT ON COLUMN hirewire.exports.file_path IS 'Path to generated export file';
COMMENT ON COLUMN hirewire.exports.error_message IS 'Error message if export failed';
