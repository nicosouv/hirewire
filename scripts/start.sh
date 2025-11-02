#!/bin/bash
# Quick start script for HireWire Web Application

set -e

echo "🚀 Starting HireWire Web Application..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
    cp .env.example .env
    echo "${GREEN}✅ .env created. Please edit it with your configuration.${NC}"
    echo ""
fi

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start PostgreSQL first
echo "📊 Starting PostgreSQL..."
docker-compose up -d postgres
echo "${GREEN}✅ PostgreSQL started${NC}"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
    echo "   Still waiting for PostgreSQL..."
    sleep 2
done
echo "${GREEN}✅ PostgreSQL is ready${NC}"
echo ""

# Start API
echo "🔧 Starting FastAPI Backend..."
docker-compose up -d --build api
echo "${GREEN}✅ API started${NC}"

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
sleep 3
until curl -s http://localhost:8000/health > /dev/null 2>&1; do
    echo "   Still waiting for API..."
    sleep 2
done
echo "${GREEN}✅ API is ready${NC}"
echo ""

# Start Frontend
echo "⚛️  Starting React Frontend..."
docker-compose up -d --build frontend
echo "${GREEN}✅ Frontend started${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${GREEN}✨ HireWire is running!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Frontend:  http://localhost:5173"
echo "🔌 API:       http://localhost:8000"
echo "📚 API Docs:  http://localhost:8000/api/v1/docs"
echo "🗄️  Database:  postgresql://postgres:password@localhost:5432/hirewire"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 Useful commands:"
echo "   make logs        - View logs"
echo "   make logs-api    - View API logs only"
echo "   make stop        - Stop all services"
echo "   make restart     - Restart services"
echo "   make help        - Show all available commands"
echo ""
echo "Press Ctrl+C to view logs (services will keep running)"
echo ""

# Follow logs
docker-compose logs -f api frontend
