#!/bin/bash
# Initialize Apache Superset with DuckDB connection

set -e

echo "🎨 Initializing Apache Superset..."

# Wait for Superset to be ready
echo "⏳ Waiting for Superset to be ready..."
until docker-compose exec -T superset curl -f http://localhost:8088/health > /dev/null 2>&1; do
    echo "Waiting for Superset..."
    sleep 5
done

echo "🔧 Setting up Superset database..."
# Initialize Superset database
docker-compose exec -T superset superset db upgrade

echo "👤 Creating admin user..."
# Create admin user (skip if already exists)
docker-compose exec -T superset superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@hirewire.local \
    --password admin || echo "Admin user already exists"

echo "🎯 Loading examples and initializing..."
# Load examples (optional)
# docker-compose exec -T superset superset load_examples

# Initialize Superset
docker-compose exec -T superset superset init

echo "🔌 Adding DuckDB database connection..."
# Add DuckDB database connection
docker-compose exec -T superset python3 -c "
from superset import app, db
from superset.models import core as models
from superset.utils.core import get_example_database

with app.app_context():
    # Check if DuckDB database already exists
    existing_db = db.session.query(models.Database).filter_by(database_name='HireWire DuckDB').first()
    
    if not existing_db:
        # Create DuckDB database connection
        database = models.Database(
            database_name='HireWire DuckDB',
            sqlalchemy_uri='duckdb:////app/duckdb-data/hirewire.duckdb',
            expose_in_sqllab=True,
            allow_ctas=True,
            allow_cvas=True,
            allow_dml=False,
            force_ctas_schema='',
            allow_run_async=True,
            allow_csv_upload=True,
            allow_file_upload=True,
        )
        
        db.session.add(database)
        db.session.commit()
        
        print('✅ DuckDB database connection created')
    else:
        print('✅ DuckDB database connection already exists')
"

echo "✅ Superset initialization completed!"
echo ""
echo "🎨 Superset is ready!"
echo "  URL: http://localhost:8088"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "📊 DuckDB connection available:"
echo "  Database: HireWire DuckDB"
echo "  URI: duckdb:////app/duckdb-data/hirewire.duckdb"
echo ""
echo "🎯 Recommended tables for dashboards:"
echo "  - mart_interview_dashboard (main dashboard)"
echo "  - mart_company_metrics (company analysis)"
echo "  - mart_monthly_trends (time series)"