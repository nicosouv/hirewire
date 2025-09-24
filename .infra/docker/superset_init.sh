#!/bin/bash

set -e

echo "🚀 Initializing Superset with HireWire configuration..."

# Wait for database to be ready
echo "⏳ Waiting for database..."
while ! pg_isready -h postgres -p 5432 -U superset; do
  sleep 1
done

echo "✅ Database is ready"

# Initialize Superset database
echo "🔧 Setting up Superset database..."
superset db upgrade

# Create admin user if it doesn't exist
echo "👤 Creating admin user..."
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@hirewire.com \
  --password admin || echo "Admin user already exists"

# Load examples and initialize
echo "📊 Loading examples and initializing..."
superset load_examples
superset init

# Import HireWire dashboards if they exist
if [ -f /app/hirewire_dashboards.zip ]; then
  echo "📈 Importing HireWire dashboards..."
  superset import-dashboards -p /app/hirewire_dashboards.zip || echo "Dashboard import failed or already exists"
fi

echo "✅ Superset initialization completed!"