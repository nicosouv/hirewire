#!/bin/bash
# Run Airflow DAG tests inside Docker container
# Usage: ./scripts/run_tests.sh [pytest options]

set -e

CONTAINER_NAME="hirewire_airflow_webserver"
TESTS_DIR="/opt/airflow/tests"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📋 Running Airflow DAG tests...${NC}"

# Copy latest test files to container
echo "Copying test files to container..."
docker exec -u root $CONTAINER_NAME rm -rf $TESTS_DIR 2>/dev/null || true
docker cp tests $CONTAINER_NAME:$TESTS_DIR
docker exec -u root $CONTAINER_NAME chmod -R 755 $TESTS_DIR

# Copy pytest configuration
if [ -f "pytest.ini" ]; then
    docker cp pytest.ini $CONTAINER_NAME:/opt/airflow/
    docker exec -u root $CONTAINER_NAME chmod 644 /opt/airflow/pytest.ini
fi

# Run tests with coverage
echo -e "${YELLOW}Running tests...${NC}"
docker exec $CONTAINER_NAME bash -c "cd /opt/airflow && python -m pytest tests/ --cov=dags --cov-report=term-missing --color=yes -v $@"

echo -e "${GREEN}✅ Tests completed${NC}"
