#!/bin/bash
# DBT Pipeline Runner for HireWire
# Pure DBT pipeline: PostgreSQL → Staging → Intermediate → Marts

set -e

echo "🚀 Starting HireWire DBT Pipeline..."

# Wait for services to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker-compose exec -T postgres pg_isready -U postgres; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "🔄 Initializing DuckDB if needed..."
docker-compose --profile init up duckdb_init

# Install DBT dependencies
echo "📦 Installing DBT dependencies..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt deps"

# Test DBT connections
echo "🔧 Testing DBT connections..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt debug"

# Run DBT pipeline: staging → intermediate → marts
echo "🔄 Running DBT pipeline..."
echo "  📊 Staging: Copy from PostgreSQL to DuckDB..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt run --select staging"

echo "  🔄 Intermediate: Clean and enrich data..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt run --select intermediate"

echo "  ✨ Marts: Create gold tables for Metabase..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt run --select marts"

# Run DBT tests
echo "🧪 Running DBT tests..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt test"

# Generate documentation
echo "📊 Generating DBT documentation..."
docker-compose exec -T dbt sh -c "cd /usr/app && dbt docs generate"

echo "✅ DBT Pipeline completed successfully!"
echo ""
echo "📈 Next steps:"
echo "  1. Access Metabase at http://localhost:3000"
echo "  2. Use mart_* tables for your dashboards"
echo "  3. Tables ready: mart_interview_dashboard, mart_company_metrics, mart_monthly_trends"