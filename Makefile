.PHONY: help dev prod stop clean logs test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development
dev: ## Start development environment (API + Frontend + DB)
	docker-compose up -d postgres api frontend
	@echo ""
	@echo "✅ Development environment started!"
	@echo "   Frontend: http://localhost:5173"
	@echo "   API: http://localhost:8000"
	@echo "   API Docs: http://localhost:8000/api/v1/docs"
	@echo "   PostgreSQL: localhost:5432"
	@echo ""
	@echo "Run 'make logs' to see logs"

dev-full: ## Start full development stack (including DBT, Superset)
	docker-compose up -d
	@echo "✅ Full development stack started!"

prod: ## Start production environment
	docker-compose -f docker-compose.prod.yml up -d
	@echo "✅ Production environment started!"
	@echo "   Application: http://localhost"

stop: ## Stop all containers
	docker-compose down
	docker-compose -f docker-compose.prod.yml down
	@echo "✅ All containers stopped"

clean: ## Stop containers and remove volumes
	docker-compose down -v
	docker-compose -f docker-compose.prod.yml down -v
	@echo "✅ Cleaned up containers and volumes"

restart: ## Restart development environment
	docker-compose restart api frontend
	@echo "✅ API and Frontend restarted"

rebuild: ## Rebuild and restart containers
	docker-compose up -d --build api frontend
	@echo "✅ Containers rebuilt and restarted"

# Logs
logs: ## Show logs from all services
	docker-compose logs -f api frontend

logs-api: ## Show API logs
	docker-compose logs -f api

logs-frontend: ## Show frontend logs
	docker-compose logs -f frontend

logs-db: ## Show database logs
	docker-compose logs -f postgres

# Database
db-shell: ## Access PostgreSQL shell
	docker-compose exec postgres psql -U postgres -d hirewire

db-migrate: ## Run database migrations (TODO: implement alembic)
	@echo "TODO: Implement Alembic migrations"

# Backend
api-shell: ## Access API container shell
	docker-compose exec api bash

api-test: ## Run backend tests
	docker-compose exec api pytest -v

api-format: ## Format backend code
	docker-compose exec api black app/
	docker-compose exec api isort app/

# Frontend
frontend-shell: ## Access frontend container shell
	docker-compose exec frontend sh

frontend-build: ## Build frontend for production
	cd frontend && npm run build

frontend-test: ## Run frontend tests
	cd frontend && npm test

# DBT
dbt-shell: ## Access DBT container shell
	docker-compose exec dbt bash

dbt-run: ## Run DBT models
	docker-compose exec dbt dbt run

dbt-test: ## Run DBT tests
	docker-compose exec dbt dbt test

dbt-docs: ## Generate and serve DBT docs
	docker-compose exec dbt dbt docs generate
	docker-compose exec dbt dbt docs serve --port 8080

# Airflow
airflow-init: ## Initialize Airflow (first time setup)
	docker-compose --profile airflow up airflow-init
	@echo ""
	@echo "✅ Airflow initialized!"
	@echo "   Run 'make airflow-start' to start Airflow services"

airflow-start: ## Start Airflow services (webserver, scheduler, worker)
	docker-compose --profile airflow up -d airflow-webserver airflow-scheduler airflow-worker airflow-postgres redis
	@echo ""
	@echo "✅ Airflow started!"
	@echo "   Airflow UI: http://localhost:8080"
	@echo "   Default credentials: admin/admin"
	@echo ""
	@echo "Run 'make airflow-logs' to see logs"

airflow-stop: ## Stop Airflow services
	docker-compose --profile airflow stop airflow-webserver airflow-scheduler airflow-worker airflow-postgres
	@echo "✅ Airflow stopped"

airflow-restart: ## Restart Airflow services
	docker-compose --profile airflow restart airflow-webserver airflow-scheduler airflow-worker
	@echo "✅ Airflow restarted"

airflow-shell: ## Access Airflow webserver shell
	docker-compose exec airflow-webserver bash

airflow-logs: ## Show Airflow logs
	docker-compose logs -f airflow-webserver airflow-scheduler airflow-worker

airflow-logs-scheduler: ## Show Airflow scheduler logs
	docker-compose logs -f airflow-scheduler

airflow-logs-worker: ## Show Airflow worker logs
	docker-compose logs -f airflow-worker

airflow-trigger-etl: ## Trigger daily ETL pipeline DAG manually
	docker-compose exec airflow-webserver airflow dags trigger daily_etl_pipeline
	@echo "✅ Daily ETL pipeline triggered"

airflow-trigger-sync: ## Trigger hourly status sync DAG manually
	docker-compose exec airflow-webserver airflow dags trigger hourly_status_sync
	@echo "✅ Hourly status sync triggered"

airflow-list-dags: ## List all Airflow DAGs
	docker-compose exec airflow-webserver airflow dags list

airflow-unpause-all: ## Unpause all DAGs
	docker-compose exec airflow-webserver airflow dags unpause daily_etl_pipeline
	docker-compose exec airflow-webserver airflow dags unpause hourly_status_sync
	@echo "✅ All DAGs unpaused"

airflow-pause-all: ## Pause all DAGs
	docker-compose exec airflow-webserver airflow dags pause daily_etl_pipeline
	docker-compose exec airflow-webserver airflow dags pause hourly_status_sync
	@echo "✅ All DAGs paused"

airflow-reset: ## Reset Airflow (clean database and re-init)
	docker-compose --profile airflow down -v
	@echo "⚠️  Airflow volumes removed"
	@echo "Run 'make airflow-init' to re-initialize"

# Combined workflows
setup: ## Initial setup (build + migrate + seed)
	@echo "🚀 Setting up HireWire..."
	docker-compose up -d postgres
	@echo "Waiting for PostgreSQL..."
	@sleep 5
	docker-compose up -d --build api frontend
	@echo ""
	@echo "✅ Setup complete!"
	@echo "   Run 'make dev' to start development"

etl: ## Run full ETL pipeline
	./scripts/etl_runner.sh
	@echo "✅ ETL pipeline completed"

health: ## Check health of all services
	@echo "Checking service health..."
	@curl -s http://localhost:8000/health | jq . || echo "❌ API not healthy"
	@curl -s http://localhost:5173 > /dev/null && echo "✅ Frontend healthy" || echo "❌ Frontend not healthy"
	@docker-compose exec -T postgres pg_isready -q && echo "✅ Database healthy" || echo "❌ Database not healthy"
