#!/bin/bash

# ETL Script to detect and mark ghosted processes
# Automatically identifies processes that have been abandoned by companies
# Based on timing patterns and lack of response

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

ghost() {
    echo -e "${PURPLE}[GHOST] $1${NC}"
}

# Check if PostgreSQL container is running
if ! docker-compose ps postgres | grep -q "Up"; then
    error "PostgreSQL container is not running. Please start with: docker-compose up -d postgres"
    exit 1
fi

log "Starting ghosted process detection..."

# Step 1: Show current ghosting candidates
log "Analyzing potential ghosted processes..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
WITH ghost_candidates AS (
    SELECT
        ip.id,
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
        END as days_since_last_interview,
        CASE
            WHEN (CURRENT_DATE - ip.application_date) > 60 AND COUNT(i.id) = 0 THEN 'No response >60 days'
            WHEN COUNT(i.id) > 0 AND MAX(i.scheduled_date) < CURRENT_DATE - INTERVAL '45 days' THEN 'Interview silence >45 days'
            WHEN ip.status = 'applied' AND (CURRENT_DATE - ip.application_date) > 30 AND COUNT(i.id) = 0 THEN 'Applied silence >30 days'
            WHEN ip.status = 'screening' AND (CURRENT_DATE - ip.application_date) > 21 AND COUNT(i.id) = 0 THEN 'Screening silence >21 days'
            ELSE 'Active'
        END as ghost_reason
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
    WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
    AND ip.status NOT IN ('ghosted', 'rejected', 'accepted', 'offer', 'withdrew')
    GROUP BY ip.id, c.name, jp.title, ip.status, ip.application_date
)
SELECT
    company,
    position,
    status as current_status,
    application_date,
    days_since_application,
    total_interviews,
    last_interview_date::date as last_interview,
    days_since_last_interview,
    ghost_reason
FROM ghost_candidates
WHERE ghost_reason != 'Active'
ORDER BY days_since_application DESC;
"

# Ask for confirmation before auto-ghosting
echo
read -p "Do you want to automatically mark these processes as 'ghosted'? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Auto-ghosting cancelled by user."
    log "You can manually review and update these processes later."
    exit 0
fi

# Step 2: Mark processes as ghosted with detailed reasoning
ghost "Marking processes as ghosted..."
GHOSTED_COUNT=$(docker-compose exec -T postgres psql -U postgres -d hirewire -c "
WITH ghost_updates AS (
    UPDATE hirewire.interview_processes ip
    SET
        status = 'ghosted',
        updated_at = CURRENT_TIMESTAMP
    FROM (
        SELECT
            ip.id,
            CASE
                WHEN (CURRENT_DATE - ip.application_date) > 60 AND
                     (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id) = 0
                THEN 'No response after ' || (CURRENT_DATE - ip.application_date) || ' days'
                WHEN (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id) > 0 AND
                     (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id) < CURRENT_DATE - INTERVAL '45 days'
                THEN 'No follow-up after interviews for ' ||
                     (CURRENT_DATE - (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id)::DATE) || ' days'
                WHEN ip.status = 'applied' AND (CURRENT_DATE - ip.application_date) > 30 AND
                     (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id) = 0
                THEN 'Applied status with no response for ' || (CURRENT_DATE - ip.application_date) || ' days'
                ELSE NULL
            END as ghost_reason
        FROM hirewire.interview_processes ip
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
        AND ip.status NOT IN ('ghosted', 'rejected', 'accepted', 'offer', 'withdrew')
    ) reasons ON ip.id = reasons.id
    WHERE reasons.ghost_reason IS NOT NULL
    RETURNING ip.id, reasons.ghost_reason
)
SELECT COUNT(*) FROM ghost_updates;
" -t | tr -d ' ')

# Step 3: Create outcome records for ghosted processes
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
INSERT INTO hirewire.interview_outcomes (process_id, outcome, outcome_date, notes)
SELECT
    ip.id,
    'ghosted',
    CURRENT_DATE,
    'Auto-detected: ' ||
    CASE
        WHEN (CURRENT_DATE - ip.application_date) > 60 AND
             (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id) = 0
        THEN 'No response after ' || (CURRENT_DATE - ip.application_date) || ' days since application'
        WHEN (SELECT COUNT(*) FROM hirewire.interviews WHERE process_id = ip.id) > 0 AND
             (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id) < CURRENT_DATE - INTERVAL '45 days'
        THEN 'No follow-up for ' ||
             (CURRENT_DATE - (SELECT MAX(scheduled_date) FROM hirewire.interviews WHERE process_id = ip.id)::DATE) || ' days after last interview'
        ELSE 'Extended period of silence'
    END
FROM hirewire.interview_processes ip
WHERE ip.status = 'ghosted'
  AND ip.updated_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute'
  AND ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
ON CONFLICT DO NOTHING;
"

success "Marked $GHOSTED_COUNT processes as ghosted"

# Step 4: Show summary of ghosted processes
if [ "$GHOSTED_COUNT" -gt "0" ]; then
    ghost "Summary of newly ghosted processes:"
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "
    SELECT
        c.name as company,
        jp.title as position,
        ip.application_date,
        CURRENT_DATE - ip.application_date as days_old,
        COALESCE(interview_count.total, 0) as interviews,
        io.notes as reason
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
    LEFT JOIN (
        SELECT process_id, COUNT(*) as total
        FROM hirewire.interviews
        GROUP BY process_id
    ) interview_count ON ip.id = interview_count.process_id
    WHERE ip.status = 'ghosted'
      AND io.outcome = 'ghosted'
      AND io.outcome_date = CURRENT_DATE
    ORDER BY days_old DESC;
    "
fi

# Step 5: Show remaining active processes
log "Remaining active processes:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    UPPER(ip.status) as status,
    COUNT(*) as count
FROM hirewire.interview_processes ip
WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
GROUP BY ip.status
ORDER BY count DESC;
"

success "Ghosted process detection completed!"

# Step 7: Audit logging
mkdir -p scripts/logs 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Detected and marked $GHOSTED_COUNT processes as ghosted" >> scripts/logs/etl_audit.log 2>/dev/null || true