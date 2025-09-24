#!/bin/bash

# ETL Script to update past scheduled interviews to completed status
# This script identifies interviews that are scheduled but have passed their scheduled_date
# and automatically updates their status to 'completed'

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

log "Starting ETL process to update past scheduled interviews..."

# Step 1: Check current status before update
log "Checking current interview status distribution..."
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    COUNT(*) as total_interviews,
    COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN scheduled_date < CURRENT_TIMESTAMP AND status = 'scheduled' THEN 1 END) as past_scheduled
FROM hirewire.interviews;
" -t

# Step 2: Show which interviews will be updated (for transparency)
log "Identifying past scheduled interviews to update..."
PAST_INTERVIEWS=$(docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    i.id,
    c.name as company_name,
    jp.title as position_title,
    i.interview_type,
    i.scheduled_date,
    EXTRACT(DAY FROM (CURRENT_TIMESTAMP - i.scheduled_date)) as days_past
FROM hirewire.interviews i
JOIN hirewire.interview_processes ip ON i.process_id = ip.id
JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
JOIN hirewire.companies c ON jp.company_id = c.id
WHERE i.scheduled_date < CURRENT_TIMESTAMP
  AND i.status = 'scheduled'
ORDER BY i.scheduled_date;
" -t)

if [[ -z "$PAST_INTERVIEWS" || "$PAST_INTERVIEWS" == *"(0 rows)"* ]]; then
    success "No past scheduled interviews found. All interviews are up to date!"
    exit 0
fi

echo -e "\n${YELLOW}Past scheduled interviews to update:${NC}"
echo "$PAST_INTERVIEWS"

# Step 3: Prompt for confirmation (optional - remove for automated runs)
read -p "Do you want to proceed with updating these interviews to 'completed'? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Update cancelled by user."
    exit 0
fi

# Step 4: Perform the update
log "Updating past scheduled interviews to completed status..."
UPDATE_RESULT=$(docker-compose exec -T postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.interviews
SET
    status = 'completed',
    updated_at = CURRENT_TIMESTAMP
WHERE scheduled_date < CURRENT_TIMESTAMP
  AND status = 'scheduled'
RETURNING id, interview_type, scheduled_date;
" -t)

# Step 5: Show results
log "Update completed. Updated interviews:"
echo "$UPDATE_RESULT"

# Step 6: Show final status distribution
log "Final interview status distribution:"
docker-compose exec -T postgres psql -U postgres -d hirewire -c "
SELECT
    COUNT(*) as total_interviews,
    COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN scheduled_date < CURRENT_TIMESTAMP AND status = 'scheduled' THEN 1 END) as remaining_past_scheduled
FROM hirewire.interviews;
" -t

success "ETL process completed successfully!"

# Step 8: Optional - Log to a file for audit trail
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated past scheduled interviews to completed" >> scripts/logs/etl_audit.log 2>/dev/null || true