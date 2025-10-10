#!/bin/bash
# Quick check script to verify HireWire setup

echo "🔍 Checking HireWire setup..."
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        echo "❌ $1"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
}

# Check Docker
docker --version > /dev/null 2>&1
check "Docker installed"

# Check docker-compose config
docker-compose config > /dev/null 2>&1
check "docker-compose.yml valid"

# Check backend structure
[ -f backend/requirements.txt ]
check "Backend requirements.txt exists"

[ -f backend/app/main.py ]
check "Backend main.py exists"

[ -f backend/app/services/process_status_service.py ]
check "ProcessStatusService exists (critical business logic)"

[ -d backend/app/models ]
check "Backend models directory exists"

[ -d backend/app/api ]
check "Backend API directory exists"

# Check frontend structure
[ -f frontend/package.json ]
check "Frontend package.json exists"

[ -f frontend/vite.config.ts ]
check "Frontend vite.config.ts exists"

[ -f frontend/src/services/api.ts ]
check "Frontend API client exists"

[ -f frontend/src/types/index.ts ]
check "Frontend TypeScript types exist"

# Check Docker files
[ -f backend/Dockerfile ]
check "Backend production Dockerfile exists"

[ -f backend/Dockerfile.dev ]
check "Backend dev Dockerfile exists"

[ -f frontend/Dockerfile ]
check "Frontend production Dockerfile exists"

[ -f frontend/Dockerfile.dev ]
check "Frontend dev Dockerfile exists"

# Check orchestration
[ -f docker-compose.yml ]
check "docker-compose.yml exists"

[ -f docker-compose.prod.yml ]
check "docker-compose.prod.yml exists"

[ -f Makefile ]
check "Makefile exists"

[ -f start.sh ]
check "start.sh script exists"

[ -x start.sh ]
check "start.sh is executable"

# Check documentation
[ -f README_WEB_APP.md ]
check "README_WEB_APP.md exists"

[ -f QUICKSTART.md ]
check "QUICKSTART.md exists"

[ -f WEB_APP_SUMMARY.md ]
check "WEB_APP_SUMMARY.md exists"

# Check configuration
[ -f backend/.env ]
check "Backend .env exists"

[ -f .env.example ]
check ".env.example exists"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo ""
    echo "✨ All checks passed! You're ready to start:"
    echo ""
    echo "   ./start.sh"
    echo ""
    echo "Or use:"
    echo "   make dev"
    echo ""
    exit 0
else
    echo ""
    echo "⚠️  Some checks failed. Please review the errors above."
    exit 1
fi
