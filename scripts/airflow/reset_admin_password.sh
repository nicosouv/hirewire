#!/bin/bash
set -e

# Reset Airflow admin password
# Usage: ./reset_admin_password.sh [username] [password]

USERNAME="${1:-admin}"
PASSWORD="${2:-admin}"

echo "🔄 Resetting Airflow admin password..."

# Delete existing user if exists and recreate
docker exec hirewire_airflow_scheduler airflow users delete --username "$USERNAME" 2>/dev/null || echo "User doesn't exist yet"

# Create user with specified credentials
docker exec hirewire_airflow_scheduler airflow users create \
  --username "$USERNAME" \
  --password "$PASSWORD" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@hirewire.com

echo "✅ Admin user created/reset successfully"
echo "👤 Credentials: $USERNAME / $PASSWORD"
echo "🌐 Login at: http://localhost:8080"
