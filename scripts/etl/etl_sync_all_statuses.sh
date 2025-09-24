#!/bin/bash

# Comprehensive ETL Script for all status synchronization
# This script handles multiple types of status updates:
# 1. Sync process status with outcomes
# 2. Auto-detect ghosted processes
# 3. Update process status based on interview progression
# 4. Mark stale processes for review

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

# Check if PostgreSQL container is running
if ! docker-compose ps postgres | grep -q "Up"; then
    error "PostgreSQL container is not running. Please start with: docker-compose up -d postgres"
    exit 1
fi

log "Starting comprehensive status synchronization..."

# Step 1: Show current status overview
log "Current status overview:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    CASE
        WHEN io.outcome IS NOT NULL THEN 'Completed (' || io.outcome || ')'
        ELSE 'Active (' || ip.status || ')'
    END as category,
    COUNT(*) as count
FROM hirewire.interview_processes ip
LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
GROUP BY
    CASE
        WHEN io.outcome IS NOT NULL THEN 'Completed (' || io.outcome || ')'
        ELSE 'Active (' || ip.status || ')'
    END
ORDER BY count DESC;
"

# Step 2: Sync process status with existing outcomes
info "Step 1/4: Syncing process status with existing outcomes..."
SYNC_COUNT=$(docker-compose exec -T postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.interview_processes ip
SET
    status = CASE
        WHEN io.outcome IN ('rejection', 'rejected') THEN 'rejected'
        WHEN io.outcome = 'ghosted' THEN 'ghosted'
        WHEN io.outcome = 'offer' THEN 'offer'
        WHEN io.outcome = 'accepted' THEN 'accepted'
        WHEN io.outcome = 'withdrew' THEN 'withdrew'
        ELSE ip.status
    END,
    updated_at = CURRENT_TIMESTAMP
FROM hirewire.interview_outcomes io
WHERE ip.id = io.process_id
  AND ip.status != CASE
        WHEN io.outcome IN ('rejection', 'rejected') THEN 'rejected'
        WHEN io.outcome = 'ghosted' THEN 'ghosted'
        WHEN io.outcome = 'offer' THEN 'offer'
        WHEN io.outcome = 'accepted' THEN 'accepted'
        WHEN io.outcome = 'withdrew' THEN 'withdrew'
        ELSE ip.status
    END
RETURNING ip.id;
" -t | grep -c '[0-9]' || echo "0")

success "Synced $SYNC_COUNT process statuses with outcomes"

# Step 3: Auto-detect and mark ghosted processes
info "Step 2/4: Auto-detecting ghosted processes..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Mark processes as ghosted based on inactivity patterns
UPDATE hirewire.interview_processes ip
SET
    status = 'ghosted',
    updated_at = CURRENT_TIMESTAMP
WHERE ip.id IN (
    WITH process_activity AS (
        SELECT
            ip.id,
            ip.status,
            ip.application_date,
            COUNT(i.id) as total_interviews,
            MAX(i.scheduled_date) as last_interview_date
        FROM hirewire.interview_processes ip
        LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes)
        AND ip.status NOT IN ('ghosted', 'rejected', 'accepted', 'offer', 'withdrew')
        GROUP BY ip.id, ip.status, ip.application_date
    )
    SELECT id FROM process_activity
    WHERE (
        -- No response after 60+ days with no interviews
        ((CURRENT_DATE - application_date) > 60 AND total_interviews = 0)
        OR
        -- Had interviews but no follow-up for 45+ days
        (total_interviews > 0 AND last_interview_date < CURRENT_DATE - INTERVAL '45 days')
        OR
        -- Applied status for 30+ days with no interviews
        (status = 'applied' AND (CURRENT_DATE - application_date) > 30 AND total_interviews = 0)
    )
);
"

# Step 4: Create ghost outcomes for newly marked processes
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Create ghost outcomes for processes marked as ghosted without existing outcomes
INSERT INTO hirewire.interview_outcomes (process_id, outcome, outcome_date, notes)
SELECT
    ip.id,
    'ghosted',
    CURRENT_DATE,
    'Auto-detected: No response after extended period'
FROM hirewire.interview_processes ip
WHERE ip.status = 'ghosted'
  AND ip.updated_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute'  -- Recently updated to ghosted
  AND ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
ON CONFLICT DO NOTHING;
"

# Step 5: Update process progression based on interviews
info "Step 3/4: Updating process progression based on interview activity..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Update to screening when first interview is scheduled
UPDATE hirewire.interview_processes ip
SET
    status = 'screening',
    updated_at = CURRENT_TIMESTAMP
WHERE ip.status = 'applied'
  AND ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes)
  AND EXISTS (
      SELECT 1 FROM hirewire.interviews i
      WHERE i.process_id = ip.id
      AND i.interview_type IN ('phone_screening', 'hr_screening', 'recruiter_call', 'video_screening')
      AND i.status IN ('scheduled', 'completed')
  );
"

docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Update to interviewing when technical interviews are involved
UPDATE hirewire.interview_processes ip
SET
    status = 'interviewing',
    updated_at = CURRENT_TIMESTAMP
WHERE ip.status IN ('applied', 'screening')
  AND ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes)
  AND (
      -- Has technical interviews
      EXISTS (
          SELECT 1 FROM hirewire.interviews i
          WHERE i.process_id = ip.id
          AND i.interview_type IN ('technical_interview', 'coding_challenge', 'technical_video', 'system_design')
          AND i.status IN ('scheduled', 'completed')
      )
      OR
      -- Has multiple interviews (indicates progression)
      (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id AND status = 'completed') >= 2
  );
"

docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Update to final_round for advanced interviews
UPDATE hirewire.interview_processes ip
SET
    status = 'final_round',
    updated_at = CURRENT_TIMESTAMP
WHERE ip.status = 'interviewing'
  AND ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes)
  AND (
      -- Has final/manager interviews
      EXISTS (
          SELECT 1 FROM hirewire.interviews i
          WHERE i.process_id = ip.id
          AND i.interview_type IN ('final_interview', 'manager_interview', 'cultural_fit', 'executive_interview')
          AND i.status IN ('scheduled', 'completed')
      )
      OR
      -- Has 3+ completed interviews
      (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id AND status = 'completed') >= 3
  );
"

# Step 6: Mark processes needing manual review
info "Step 4/4: Identifying processes needing manual review..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
-- Processes that might need manual status update
SELECT
    '🔍 NEEDS REVIEW' as alert,
    c.name as company,
    jp.title as position,
    ip.status,
    ip.application_date,
    CURRENT_DATE - ip.application_date as days_old,
    COUNT(i.id) as interviews,
    MAX(i.scheduled_date) as last_interview
FROM hirewire.interview_processes ip
JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
JOIN hirewire.companies c ON jp.company_id = c.id
LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes)
AND (
    -- Long-running screening
    (ip.status = 'screening' AND (CURRENT_DATE - ip.application_date) > 21)
    OR
    -- Long-running interviewing without recent activity
    (ip.status = 'interviewing' AND
     COALESCE((SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id), ip.application_date::timestamp)
     < CURRENT_DATE - INTERVAL '14 days')
    OR
    -- Reminder status processes
    (ip.status = 'reminder')
)
GROUP BY ip.id, c.name, jp.title, ip.status, ip.application_date
HAVING COUNT(i.id) > 0 OR ip.status != 'applied'
ORDER BY days_old DESC;
"

# Step 7: Final status summary
log "Final status distribution:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    CASE
        WHEN io.outcome IS NOT NULL THEN '✅ ' || UPPER(io.outcome)
        ELSE '🔄 ' || UPPER(ip.status)
    END as status_category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM hirewire.interview_processes ip
LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
GROUP BY
    CASE
        WHEN io.outcome IS NOT NULL THEN '✅ ' || UPPER(io.outcome)
        ELSE '🔄 ' || UPPER(ip.status)
    END
ORDER BY count DESC;
"

# Step 8: Show recent changes summary
log "Summary of recent changes (last 2 minutes):"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    c.name as company,
    jp.title as position,
    ip.status as new_status,
    CASE
        WHEN io.outcome IS NOT NULL THEN '(' || io.outcome || ')'
        ELSE ''
    END as outcome,
    ip.updated_at
FROM hirewire.interview_processes ip
JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
JOIN hirewire.companies c ON jp.company_id = c.id
LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
WHERE ip.updated_at >= CURRENT_TIMESTAMP - INTERVAL '2 minutes'
ORDER BY ip.updated_at DESC;
"

success "Comprehensive status synchronization completed!"

# Step 10: Audit log
mkdir -p scripts/logs 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Comprehensive status sync completed" >> scripts/logs/etl_audit.log 2>/dev/null || true