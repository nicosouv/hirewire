#!/bin/bash
# Backend test runner with options

# Default options
COVERAGE=false
VERBOSE=false
MARKERS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cov|--coverage)
            COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -m|--markers)
            MARKERS="-m $2"
            shift 2
            ;;
        *)
            # Pass through to pytest
            PYTEST_ARGS="$PYTEST_ARGS $1"
            shift
            ;;
    esac
done

# Build command
CMD="pytest"

if [ "$COVERAGE" = true ]; then
    CMD="$CMD --cov=app --cov-report=term-missing --cov-report=html"
fi

if [ "$VERBOSE" = true ]; then
    CMD="$CMD -v"
else
    CMD="$CMD -q"
fi

if [ -n "$MARKERS" ]; then
    CMD="$CMD $MARKERS"
fi

CMD="$CMD $PYTEST_ARGS"

# Run tests
echo "Running: $CMD"
eval $CMD
