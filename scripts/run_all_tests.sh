#!/bin/bash
# Run all tests (backend, frontend, airflow, E2E)

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Running HireWire Test Suite${NC}\n"

FAILED=0

# Backend tests
echo -e "${YELLOW}📦 Backend Tests${NC}"
cd backend
if pytest --cov=app --cov-report=term-missing -q; then
    echo -e "${GREEN}✅ Backend tests passed${NC}\n"
else
    echo -e "${RED}❌ Backend tests failed${NC}\n"
    FAILED=1
fi
cd ..

# Frontend tests
echo -e "${YELLOW}⚛️  Frontend Tests${NC}"
cd frontend
if npm test -- --run; then
    echo -e "${GREEN}✅ Frontend tests passed${NC}\n"
else
    echo -e "${RED}❌ Frontend tests failed${NC}\n"
    FAILED=1
fi
cd ..

# Airflow DAG tests
echo -e "${YELLOW}🌊 Airflow DAG Tests${NC}"
cd airflow
if ./scripts/run_tests.sh --tb=short -q; then
    echo -e "${GREEN}✅ Airflow tests passed${NC}\n"
else
    echo -e "${RED}❌ Airflow tests failed${NC}\n"
    FAILED=1
fi
cd ..

# Summary
echo -e "\n${YELLOW}📊 Test Summary${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
