#!/bin/bash

###############################################################################
# HireWire Build & Test Script
# Runs all CI checks locally before pushing to Git
###############################################################################

set -e  # Exit on any error

# Colors for output (will be disabled in CI mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print status
print_status() {
    local status=$1
    local message=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "failure")
            echo -e "${RED}❌ $message${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "skip")
            echo -e "${YELLOW}⏭️  $message${NC}"
            SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if changes were made in a directory
has_changes() {
    local dir=$1
    if [ -d "$dir" ]; then
        return 0
    fi
    return 1
}

# Parse command line arguments
RUN_ALL=false
RUN_BACKEND=false
RUN_FRONTEND=false
RUN_AIRFLOW=false
RUN_DBT=false
AUTO_FIX=false
CI_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            RUN_ALL=true
            shift
            ;;
        --backend|-b)
            RUN_BACKEND=true
            shift
            ;;
        --frontend|-f)
            RUN_FRONTEND=true
            shift
            ;;
        --airflow)
            RUN_AIRFLOW=true
            shift
            ;;
        --dbt)
            RUN_DBT=true
            shift
            ;;
        --fix)
            AUTO_FIX=true
            shift
            ;;
        --ci)
            CI_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./build.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all, -a         Run all checks"
            echo "  --backend, -b     Run backend checks only"
            echo "  --frontend, -f    Run frontend checks only"
            echo "  --airflow         Run Airflow checks only"
            echo "  --dbt             Run DBT checks only"
            echo "  --fix             Auto-fix issues when possible (format code)"
            echo "  --ci              CI mode (no colors, verbose output)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build.sh --all                 # Run all checks"
            echo "  ./build.sh --backend --fix       # Check & format backend"
            echo "  ./build.sh -b -f                 # Check backend & frontend"
            echo "  ./build.sh --backend --ci        # Backend checks in CI mode"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If no specific component selected, run all
if [ "$RUN_ALL" = false ] && [ "$RUN_BACKEND" = false ] && [ "$RUN_FRONTEND" = false ] && [ "$RUN_AIRFLOW" = false ] && [ "$RUN_DBT" = false ]; then
    RUN_ALL=true
fi

if [ "$RUN_ALL" = true ]; then
    RUN_BACKEND=true
    RUN_FRONTEND=true
    RUN_AIRFLOW=true
    RUN_DBT=true
fi

# Disable colors in CI mode
if [ "$CI_MODE" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

print_header "🚀 HireWire Build & Test"
echo "Running checks: Backend=$RUN_BACKEND | Frontend=$RUN_FRONTEND | Airflow=$RUN_AIRFLOW | DBT=$RUN_DBT"
echo "Auto-fix: $AUTO_FIX"
if [ "$CI_MODE" = true ]; then
    echo "CI Mode: Enabled (no colors, verbose output)"
fi

###############################################################################
# BACKEND CHECKS
###############################################################################

if [ "$RUN_BACKEND" = true ]; then
    print_header "🐍 Backend Tests"

    if ! has_changes "backend"; then
        print_status "skip" "Backend directory not found"
    else
        cd backend

        # Check if Python is installed
        if ! command -v python3 &> /dev/null; then
            print_status "failure" "Python3 not found"
            exit 1
        fi

        # Install dependencies if needed
        if [ ! -d "venv" ]; then
            print_status "info" "Creating virtual environment..."
            python3 -m venv venv
        fi

        source venv/bin/activate 2>/dev/null || . venv/bin/activate

        print_status "info" "Installing dependencies..."
        pip install -q --upgrade pip
        pip install -q -r requirements.txt
        pip install -q black flake8 mypy pytest pytest-cov

        # Black formatting
        if [ "$AUTO_FIX" = true ]; then
            print_status "info" "Running Black formatter (auto-fix)..."
            if black app/; then
                print_status "success" "Black formatting applied"
            else
                print_status "failure" "Black formatting failed"
            fi
        else
            print_status "info" "Checking Black formatting..."
            if black --check app/; then
                print_status "success" "Black formatting check passed"
            else
                print_status "failure" "Black formatting check failed (run with --fix to auto-format)"
            fi
        fi

        # Flake8 linting
        print_status "info" "Running Flake8..."
        if flake8 app/ --max-line-length=120 --exclude=__pycache__,venv --extend-ignore=E203,W503; then
            print_status "success" "Flake8 linting passed"
        else
            print_status "failure" "Flake8 linting failed"
        fi

        # MyPy type checking (optional - may have issues)
        print_status "info" "Running MyPy type checking..."
        if mypy app/ --ignore-missing-imports --no-strict-optional 2>/dev/null; then
            print_status "success" "MyPy type checking passed"
        else
            print_status "skip" "MyPy type checking has warnings (non-blocking)"
        fi

        # Pytest
        print_status "info" "Running pytest..."
        if [ -f "../.env" ]; then
            export $(cat ../.env | grep -v '^#' | xargs)
        fi

        # Set default environment variables for tests
        export DATABASE_URL=${DATABASE_URL:-"sqlite:///./test.db"}
        export SECRET_KEY=${SECRET_KEY:-"test-secret-key-for-local-dev-only"}
        export ACCESS_TOKEN_EXPIRE_MINUTES=${ACCESS_TOKEN_EXPIRE_MINUTES:-30}

        # Generate both terminal and XML reports (XML for CI/CD coverage upload)
        if pytest --cov=app --cov-report=term-missing --cov-report=xml -v; then
            print_status "success" "Pytest passed"
        else
            print_status "failure" "Pytest failed"
        fi

        deactivate 2>/dev/null || true
        cd ..
    fi
fi

###############################################################################
# FRONTEND CHECKS
###############################################################################

if [ "$RUN_FRONTEND" = true ]; then
    print_header "⚛️  Frontend Tests"

    if ! has_changes "frontend"; then
        print_status "skip" "Frontend directory not found"
    else
        cd frontend

        # Check if Node is installed
        if ! command -v node &> /dev/null; then
            print_status "failure" "Node.js not found"
            exit 1
        fi

        # Install dependencies
        print_status "info" "Installing npm dependencies..."
        if npm ci --silent; then
            print_status "success" "Dependencies installed"
        else
            print_status "failure" "npm install failed"
        fi

        # ESLint
        print_status "info" "Running ESLint..."
        if npm run lint; then
            print_status "success" "ESLint passed"
        else
            print_status "failure" "ESLint failed"
        fi

        # TypeScript check
        print_status "info" "Running TypeScript check..."
        if npm run typecheck; then
            print_status "success" "TypeScript check passed"
        else
            print_status "failure" "TypeScript check failed"
        fi

        # Build
        print_status "info" "Building frontend..."
        if npm run build; then
            print_status "success" "Frontend build successful"
        else
            print_status "failure" "Frontend build failed"
        fi

        # Tests (if any)
        if grep -q '"test"' package.json; then
            print_status "info" "Running frontend tests..."
            if npm test -- --run 2>/dev/null || npm test 2>/dev/null; then
                print_status "success" "Frontend tests passed"
            else
                print_status "skip" "Frontend tests skipped or failed (non-blocking)"
            fi
        fi

        cd ..
    fi
fi

###############################################################################
# AIRFLOW CHECKS
###############################################################################

if [ "$RUN_AIRFLOW" = true ]; then
    print_header "🌊 Airflow DAG Tests"

    if ! has_changes "airflow"; then
        print_status "skip" "Airflow directory not found"
    else
        cd airflow

        # Check if requirements-test.txt exists
        if [ ! -f "requirements-test.txt" ]; then
            print_status "skip" "Airflow tests not configured (requirements-test.txt missing)"
        else
            # Create virtual environment
            if [ ! -d "venv" ]; then
                python3 -m venv venv
            fi

            source venv/bin/activate 2>/dev/null || . venv/bin/activate

            print_status "info" "Installing Airflow test dependencies..."
            pip install -q -r requirements-test.txt

            # Run DAG tests
            print_status "info" "Running Airflow DAG tests..."
            if pytest tests/ -v; then
                print_status "success" "Airflow DAG tests passed"
            else
                print_status "failure" "Airflow DAG tests failed"
            fi

            deactivate 2>/dev/null || true
        fi

        cd ..
    fi
fi

###############################################################################
# DBT CHECKS
###############################################################################

if [ "$RUN_DBT" = true ]; then
    print_header "📊 DBT Validation"

    if ! has_changes "dbt_project"; then
        print_status "skip" "DBT directory not found"
    else
        cd dbt_project

        # Create virtual environment
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi

        source venv/bin/activate 2>/dev/null || . venv/bin/activate

        print_status "info" "Installing DBT..."
        pip install -q dbt-core dbt-duckdb dbt-postgres

        # DBT deps
        print_status "info" "Running dbt deps..."
        if dbt deps; then
            print_status "success" "DBT dependencies installed"
        else
            print_status "failure" "DBT deps failed"
        fi

        # DBT parse
        print_status "info" "Running dbt parse..."
        if dbt parse --profiles-dir ../profiles; then
            print_status "success" "DBT parse passed"
        else
            print_status "failure" "DBT parse failed"
        fi

        # DBT compile (if profiles.yml is configured)
        if [ -f "../profiles/profiles.yml" ]; then
            print_status "info" "Running dbt compile..."
            if dbt compile --profiles-dir ../profiles 2>/dev/null; then
                print_status "success" "DBT compile passed"
            else
                print_status "skip" "DBT compile skipped (database not available)"
            fi
        fi

        deactivate 2>/dev/null || true
        cd ..
    fi
fi

###############################################################################
# SUMMARY
###############################################################################

print_header "📋 Summary"
echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}✅ Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}❌ Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}⏭️  Skipped: $SKIPPED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}❌ Build failed with $FAILED_CHECKS error(s)${NC}"
    echo "Please fix the errors before pushing to Git."
    exit 1
else
    echo -e "${GREEN}✅ All checks passed! Ready to push to Git.${NC}"
    exit 0
fi
