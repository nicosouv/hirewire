#!/bin/bash

# ETL Script to auto-update process status based on interview activity
# This script intelligently updates process status based on:
# - Scheduled interviews (upcoming)
# - Completed interviews (progress tracking)
# - Interview patterns and timing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if PostgreSQL container is running
if ! docker-compose ps postgres | grep -q "Up"; then
    error "PostgreSQL container is not running. Please start with: docker-compose up -d postgres"
    exit 1
fi

log "Starting intelligent process status updates based on interview activity..."

# Step 1: Show current status distribution
log "Current process status distribution:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM hirewire.interview_processes
WHERE id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew'))
GROUP BY status
ORDER BY count DESC;
"

# Step 2: Update processes that should be 'screening' based on scheduled interviews
log "Updating processes to 'screening' status..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.interview_processes
SET
    status = 'screening',
    updated_at = CURRENT_TIMESTAMP
WHERE id IN (
    SELECT DISTINCT ip.id
    FROM hirewire.interview_processes ip
    JOIN hirewire.interviews i ON ip.id = i.process_id
    WHERE ip.status = 'applied'
      AND i.status = 'scheduled'
      AND i.interview_type IN ('phone_screening', 'hr_screening', 'recruiter_call', 'video_screening')
      AND i.scheduled_date >= CURRENT_TIMESTAMP - INTERVAL '1 day'  -- Recent or future
    -- Only if no final outcome exists
    AND ip.id NOT IN (
        SELECT DISTINCT process_id
        FROM hirewire.interview_outcomes
        WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
    )
);
"

# Step 3: Update processes to 'interviewing' based on technical/multiple interviews
log "Updating processes to 'interviewing' status..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.interview_processes
SET
    status = 'interviewing',
    updated_at = CURRENT_TIMESTAMP
WHERE id IN (
    SELECT DISTINCT ip.id
    FROM hirewire.interview_processes ip
    WHERE ip.status IN ('applied', 'screening')
    AND (
        -- Has technical interviews scheduled/completed
        EXISTS (
            SELECT 1 FROM hirewire.interviews i
            WHERE i.process_id = ip.id
            AND i.interview_type IN ('technical_interview', 'coding_challenge', 'technical_video', 'system_design', 'pair_programming')
            AND (i.status = 'scheduled' AND i.scheduled_date >= CURRENT_TIMESTAMP - INTERVAL '1 day' OR i.status = 'completed')
        )
        OR
        -- Has multiple completed interviews (indicates advanced stage)
        (
            SELECT COUNT(*) FROM hirewire.interviews i
            WHERE i.process_id = ip.id AND i.status = 'completed'
        ) >= 2
        OR
        -- Has scheduled interviews beyond screening
        EXISTS (
            SELECT 1 FROM hirewire.interviews i
            WHERE i.process_id = ip.id
            AND i.status = 'scheduled'
            AND i.interview_type NOT IN ('phone_screening', 'hr_screening', 'recruiter_call', 'video_screening')
        )
    )
    -- Only if no final outcome exists
    AND ip.id NOT IN (
        SELECT DISTINCT process_id
        FROM hirewire.interview_outcomes
        WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
    )
);
"

# Step 4: Update processes to 'final_round' based on interview patterns
log "Updating processes to 'final_round' status..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.interview_processes
SET
    status = 'final_round',
    updated_at = CURRENT_TIMESTAMP
WHERE id IN (
    SELECT DISTINCT ip.id
    FROM hirewire.interview_processes ip
    WHERE ip.status = 'interviewing'
    AND (
        -- Has final/manager interviews scheduled
        EXISTS (
            SELECT 1 FROM hirewire.interviews i
            WHERE i.process_id = ip.id
            AND i.interview_type IN ('final_interview', 'manager_interview', 'cultural_fit', 'executive_interview')
            AND (i.status = 'scheduled' OR i.status = 'completed')
        )
        OR
        -- Has 3+ completed interviews (likely in final stages)
        (
            SELECT COUNT(*) FROM hirewire.interviews i
            WHERE i.process_id = ip.id AND i.status = 'completed'
        ) >= 3
    )
    -- Only if no final outcome exists
    AND ip.id NOT IN (
        SELECT DISTINCT process_id
        FROM hirewire.interview_outcomes
        WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
    )
);
"

# Step 5: Identify processes that might need manual attention (stale processes)
log "Identifying processes that may need manual review:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    c.name as company,
    jp.title as position,
    ip.status,
    ip.application_date,
    CURRENT_DATE - ip.application_date as days_since_application,
    COUNT(i.id) as total_interviews,
    MAX(i.scheduled_date) as last_interview_date,
    CASE
        WHEN MAX(i.scheduled_date) IS NOT NULL THEN
            CURRENT_DATE - MAX(i.scheduled_date)::DATE
        ELSE NULL
    END as days_since_last_interview
FROM hirewire.interview_processes ip
JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
JOIN hirewire.companies c ON jp.company_id = c.id
LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
WHERE ip.id NOT IN (
    SELECT DISTINCT process_id
    FROM hirewire.interview_outcomes
    WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
)
AND (
    -- Applied for >14 days with no interviews
    (ip.status = 'applied' AND (CURRENT_DATE - ip.application_date) > 14)
    OR
    -- Screening/interviewing with no recent activity
    (ip.status IN ('screening', 'interviewing') AND
     (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id) < CURRENT_DATE - INTERVAL '10 days')
)
GROUP BY ip.id, c.name, jp.title, ip.status, ip.application_date
ORDER BY days_since_application DESC;
"

# Step 6: Show final status distribution after updates
log "Process status distribution after updates:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM hirewire.interview_processes
WHERE id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew'))
GROUP BY status
ORDER BY count DESC;
"

# Step 7: Show summary of changes made
log "Summary of status updates made:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    c.name as company,
    jp.title as position,
    ip.status as new_status,
    COUNT(i.id) as total_interviews,
    COUNT(CASE WHEN i.status = 'scheduled' THEN 1 END) as scheduled_interviews,
    MAX(CASE WHEN i.status = 'scheduled' THEN i.scheduled_date END) as next_interview
FROM hirewire.interview_processes ip
JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
JOIN hirewire.companies c ON jp.company_id = c.id
LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
WHERE ip.updated_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute'  -- Recently updated
GROUP BY ip.id, c.name, jp.title, ip.status
ORDER BY c.name;
"

success "Process status updates completed successfully!"

# Step 9: Optional - Log to audit trail
mkdir -p scripts/logs 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated process statuses based on interview activity" >> scripts/logs/etl_audit.log 2>/dev/null || true