![HireWire](https://github.com/nicosouv/hirewire/blob/main/frontend/public/logo.png?raw=true)

# Interview Analytics Platform

A modern full-stack application to track and analyze job interview processes. Built with a complete web interface, automated ETL pipelines, and advanced analytics capabilities.

## Key Features

**Web Application**:
- Kanban board for visual pipeline management (Applied → Screening → Interviewing → Final Round → Closed)
- Quick Add Modal: Create company + position + application in one form (2 clicks instead of 11 steps)
- Application Detail Panel: Edit details, add interviews, view timeline without page navigation
- Priority Actions: Smart notifications for upcoming interviews, overdue follow-ups, and stale applications
- Real-time search and filtering across all applications

**Automated ETL**:
- Airflow DAGs for scheduled data refreshes (daily full sync, hourly incremental updates)
- Auto-detect ghosted processes based on inactivity patterns
- Auto-update process status based on interview progress
- Auto-mark past scheduled interviews as completed

**Export & Reporting**:
- Generate comprehensive Excel/CSV reports with summary, applications, interviews, and company stats
- Flexible date range selection
- Asynchronous processing with email delivery
- Track export history and status

**Analytics**:
- Star schema in DuckDB for fast analytical queries
- DBT transformations with data quality tests
- Apache Superset dashboards for visualizations
- Marts for active applications, interview analytics, and daily stats

## Architecture

This project uses a modern data stack optimized for both transactional and analytical workloads:

- **React + TypeScript Frontend**: Modern web UI with Kanban board, side panels, and smart priority actions
- **FastAPI Backend**: REST API with JWT authentication, role-based access, and business logic layer
- **PostgreSQL**: Primary database for transactional data (applications, interviews, users)
- **DBT**: Data transformation layer orchestrating PostgreSQL → DuckDB pipeline
- **DuckDB**: Columnar analytics database with star schema for fast analytical queries
- **Apache Superset**: Modern dashboarding and visualization platform
- **Apache Airflow 3**: Orchestration platform for automated ETL workflows with Celery executor

## Why This Stack?

**Data Layer**:
- PostgreSQL handles transactional operations with ACID guarantees
- DuckDB excels at analytical queries with columnar storage
- DBT provides data modeling, testing, and documentation

**Application Layer**:
- FastAPI offers high performance with async support and automatic OpenAPI docs
- React + TypeScript provides type-safe frontend development
- TanStack Query handles data fetching, caching, and state management

**Orchestration**:
- Airflow automates ETL workflows with retry logic, monitoring, and alerting
- Celery executor enables parallel task execution
- Replaces manual cron jobs with centralized observable pipelines

## Project Structure

```
hirewire/
├── docker-compose.yml           # Service orchestration
├── frontend/                    # React + TypeScript application
│   ├── src/
│   │   ├── pages/              # Main pages (Dashboard, Applications, Login)
│   │   ├── components/         # Reusable UI components
│   │   ├── hooks/              # Custom React hooks for API calls
│   │   ├── contexts/           # Auth context and state management
│   │   └── services/           # API client configuration
│   └── package.json
├── backend/                     # FastAPI application
│   ├── app/
│   │   ├── api/v1/endpoints/   # API route handlers
│   │   ├── models/             # SQLAlchemy ORM models
│   │   ├── schemas/            # Pydantic validation schemas
│   │   ├── services/           # Business logic layer
│   │   ├── core/               # Configuration, security, database
│   │   └── main.py             # FastAPI app entry point
│   └── requirements.txt
├── sql/
│   ├── postgres/               # PostgreSQL schemas (raw data)
│   └── duckdb/                 # DuckDB star schema + ETL views
├── dbt_project/
│   ├── models/
│   │   ├── staging/            # Extract from PostgreSQL
│   │   ├── intermediate/       # Business logic transformations
│   │   └── marts/              # Analytics-ready tables
│   └── macros/                 # Custom DBT macros (postgres_scan)
├── airflow/
│   ├── dags/                   # Airflow DAG definitions
│   └── plugins/                # Custom operators/hooks
├── scripts/
│   ├── data_entry/             # Interactive data entry scripts
│   ├── etl/                    # ETL automation scripts (legacy)
│   ├── airflow/                # Airflow helper scripts
│   └── main.sh                 # Central script manager
└── profiles/                   # DBT connection configs
```

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git
- `.env` file with required configuration (see Environment Configuration section)

### Initial Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/hirewire.git
cd hirewire
```

2. **Create `.env` file**
```bash
cp .env.example .env
# Edit .env with your configuration (see Environment Configuration section)
```

3. **Start core services**
```bash
docker-compose up -d --build
```

4. **Start Airflow (optional but recommended)**
```bash
docker-compose --profile airflow up -d
```

5. **Run the complete ETL pipeline**
```bash
./scripts/etl_runner.sh
```

6. **Test the setup**
```bash
./scripts/test_setup.sh
```

### Available Services

- **Web Application**: http://localhost:5173 (React UI with Kanban board)
- **Backend API**: http://localhost:8000 (FastAPI with Swagger docs at /docs)
- **PostgreSQL**: `localhost:5432` (postgres/password/hirewire)
- **Apache Airflow**: http://localhost:8081 (secured via JWT + Nginx proxy)
- **Apache Superset**: http://localhost:8088 (admin/admin, requires `--profile superset`)
- **DuckDB**: File-based in Docker volume at `/data/hirewire.duckdb`

### Default Login Credentials

**Web Application**:
- Email: `admin@hirewire.com`
- Password: `secret`

**Airflow Access**:
- Must login via web app first (JWT authentication)
- Access http://localhost:8081 (automatically authenticated via Nginx proxy)
- Requires `is_airflow_admin = true` in user database record

**Superset**:
- Username: `admin`
- Password: `admin`

## Data Model

### Core Entities

The platform tracks my job search through these key entities:

1. **Companies**: Organizations I'm applying to
2. **Job Positions**: Specific roles at each company
3. **Interview Processes**: Application attempts (one per position attempt)
4. **Interviews**: Individual interview rounds within a process
5. **Interview Outcomes**: Final results (offer, rejection, etc.)

### Entity Relationships

```
COMPANY (1) → (n) JOB_POSITION (1) → (n) PROCESS (1) → (n) INTERVIEW
                                           ↓
                                    (0..1) OUTCOME
```

Key rule: **One active process per position at a time**. Multiple processes for the same position represent different application attempts over time.

## Data Entry Workflow

### Web Application (Recommended)

The modern web UI provides an intuitive interface for data entry:

1. **Quick Add Modal**: One-click application creation
   - Create company + position + application in a single form
   - Inline company/position creation without page navigation
   - Reduces workflow from 11 steps to 2 clicks

2. **Kanban Board**: Visual pipeline management
   - Drag applications between stages (applied → screening → interviewing → final round)
   - Click any card to open detailed side panel
   - Search and filter by status, company, or position

3. **Application Detail Panel**:
   - Edit status inline with dropdown selector
   - Add interviews directly from the panel
   - View complete timeline without navigation

### Command Line (Alternative)

Interactive scripts for automation:

```bash
./scripts/main.sh data-entry add-company     # If new company
./scripts/main.sh data-entry add-job         # If new position
./scripts/main.sh data-entry add-process     # Start new application
./scripts/main.sh data-entry add-interview   # Add interview round
./scripts/main.sh data-entry add-outcome     # Final result
```

## Apache Airflow - Automated ETL

The platform uses Apache Airflow 3 for automated ETL workflows, replacing manual bash scripts with observable, scheduled pipelines.

### Airflow Architecture

**Security**: Airflow UI is secured via Nginx reverse proxy with JWT validation. Users must:
1. Login via React app (http://localhost:5173)
2. Have `is_airflow_admin = true` in database
3. Access Airflow at http://localhost:8081 (automatically authenticated)

**Components**:
- **DAG Processor**: Scans `/opt/airflow/dags` every 30 seconds
- **Scheduler**: Schedules DAG runs based on parsed DAGs
- **Worker**: Executes tasks using Celery executor
- **Webserver**: Provides UI and REST API

### Available DAGs

**`daily_etl_pipeline`** (Daily at 2 AM Paris time):
- Complete data refresh with quality checks
- Tasks: Install DBT deps → Run staging → Run intermediate → Run marts → Run tests → Generate docs → Verify DuckDB

**`hourly_status_sync`** (Hourly, 9 AM - 7 PM Mon-Fri):
- Quick incremental updates during business hours
- Tasks: Refresh active applications → Refresh interview summary → Check data freshness → Monitor stale applications

**`update_process_status`** (Hourly, 9 AM - 7 PM Mon-Fri):
- Auto-update process status based on interview activity:
  - `applied` → `screening` (when screening interview scheduled)
  - `applied`/`screening` → `interviewing` (when technical interviews or 2+ completed)
  - `interviewing` → `final_round` (when final interview or 3+ completed)
- Calls API endpoint: `/api/v1/airflow/tasks/update-process-status`

**`update_past_interviews`** (Every 6 hours):
- Update interviews from `scheduled` → `completed` when scheduled_date has passed
- Calls API endpoint: `/api/v1/airflow/tasks/update-past-interviews`

**`detect_ghosted_processes`** (Daily at 4 AM Paris time):
- Auto-detect ghosted processes based on inactivity patterns
- Mark detected processes as `ghosted` and create outcomes
- Calls API endpoint: `/api/v1/airflow/tasks/detect-ghosted-processes`

**`generate_export_report`** (On-demand via API):
- Extract user data from DuckDB (filtered by date range)
- Generate Excel/CSV report with multiple sheets
- Send email with attachment via SMTP
- Update export status in database

### Airflow Commands

```bash
# Access Airflow CLI
docker-compose exec airflow-webserver bash

# List all DAGs
airflow dags list

# Trigger DAG manually
airflow dags trigger daily_etl_pipeline

# Pause/unpause DAG
airflow dags pause daily_etl_pipeline
airflow dags unpause daily_etl_pipeline

# View logs
docker-compose logs -f airflow-scheduler
docker-compose logs -f airflow-worker

# Force DAG discovery
docker exec hirewire_airflow_scheduler airflow dags reserialize
```

### Granting Airflow Access

```sql
-- Grant Airflow admin access to a user
UPDATE hirewire.users
SET is_airflow_admin = TRUE
WHERE email = 'user@example.com';
```

### Legacy ETL Scripts (Deprecated)

The following bash scripts are deprecated and replaced by Airflow DAGs:
- `scripts/etl/etl_update_process_status.sh` → Use `update_process_status` DAG
- `scripts/etl/etl_update_past_interviews.sh` → Use `update_past_interviews` DAG
- `scripts/etl/etl_sync_all_statuses.sh` → Use `detect_ghosted_processes` DAG

## DBT Workflow

### Development Commands
```bash
# Access DBT container
docker-compose exec dbt bash

# Install dependencies
dbt deps

# Run specific model layers
dbt run --models staging        # Extract from PostgreSQL
dbt run --models intermediate   # Business logic layer
dbt run --models marts         # Analytics tables

# Test data quality
dbt test

# Generate documentation
dbt docs generate && dbt docs serve
```

### Model Hierarchy

1. **Staging Models**: One-to-one mapping with source PostgreSQL tables
2. **Intermediate Models**: Enriched with calculated fields and business logic
3. **Mart Models**: Final aggregated tables optimized for Superset dashboards

Key models:
- `mart_active_applications`: Current job applications with smart next actions
- `mart_interview_analytics`: Interview performance and patterns
- `mart_application_daily_stats`: Daily application metrics

## Export System

The platform includes a comprehensive export system for generating job search reports and delivering them via email.

### Export Features

- **Flexible date range**: Export data for any period
- **Multiple formats**: Excel (recommended) or CSV
- **Comprehensive data**:
  - Summary statistics (applications, offers, rejections, interviews)
  - Detailed applications list
  - Complete interview timeline
  - Company statistics
- **Asynchronous processing**: User receives email when ready (no waiting)
- **Status tracking**: View export history in real-time

### Excel Export Contents

The Excel file contains 4 sheets:

1. **Summary**: Total applications, offers, rejections, interviews, avg days to first interview
2. **Applications**: Detailed list with company, position, status, dates, interview count, notes
3. **Interviews**: Complete timeline with round, type, interviewer, status, notes
4. **Companies**: Statistics by company (application count, interview count, latest status)

### Using the Export System

**Via Web Interface** (recommended):
1. Navigate to Overview page
2. Click "Export Report" button
3. Fill in date range, format, and email
4. Click "Request Export"
5. Receive email with attachment (1-3 minutes)

**Via API**:
```bash
curl -X POST "http://localhost:8000/api/v1/exports/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "start_date": "2024-10-01",
    "end_date": "2025-01-12",
    "format": "excel",
    "recipient_email": "user@example.com"
  }'
```

### SMTP Configuration

Exports require SMTP settings in `.env`:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password  # For Gmail: use App Password, not account password
SMTP_FROM=noreply@hirewire.com
```

**Gmail Setup**:
1. Enable 2-Factor Authentication in Google Account
2. Generate App Password at https://myaccount.google.com/apppasswords
3. Use the 16-character password in `.env`

See `EXPORTS_GUIDE.md` for detailed troubleshooting and alternative SMTP providers.

## Database Access

### PostgreSQL (Raw Data)
```bash
docker-compose exec postgres psql -U postgres -d hirewire
```

### DuckDB (Analytics)

**Important**: DuckDB file lives in a Docker volume (`duckdb_data`), not in `./data/` on your local filesystem.

**Option 1: Copy to local system** (recommended):
```bash
./scripts/sync_duckdb_local.sh
# Then access at ./data/hirewire.duckdb
```

**Option 2: Execute queries directly in container**:
```bash
docker-compose exec dbt python -c "
import duckdb
conn = duckdb.connect('/data/hirewire.duckdb')
result = conn.execute('SELECT * FROM mart_active_applications').fetchall()
for row in result: print(row)
"
```

**Option 3: Manual copy from Docker volume**:
```bash
docker cp hirewire_dbt:/data/hirewire.duckdb ./data/hirewire.duckdb
```

## Apache Superset Setup

### Initial Configuration

Superset runs on port 8088 with admin/admin credentials. To connect to DuckDB:

1. Go to Settings → Database Connections
2. Add new database with:
   - **Database**: DuckDB
   - **SQLAlchemy URI**: `duckdb:////duckdb-data/hirewire.duckdb`
   - Test connection and save

### Key Dashboards

I've built dashboards for:
- Active applications with next actions
- Interview pipeline analytics
- Monthly application trends
- Company and position tracking

## Development

### Frontend Development

```bash
cd frontend

# Install dependencies
npm install

# Start dev server (localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Linting
npm run lint
```

**Frontend Architecture**:
- **State Management**: TanStack Query (React Query) for data fetching and caching
- **Routing**: React Router with URL-based filtering
- **Styling**: Tailwind CSS with custom color system
- **Key Components**:
  - `QuickAddModal`: One-click application creation
  - `ApplicationDetailPanel`: Side panel for viewing/editing
  - `PriorityActions`: Smart priority logic
  - `ApplicationCard`: Reusable Kanban card

### Backend Development

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest

# Run tests with coverage
pytest --cov=app --cov-report=html

# Code formatting
black app/

# Linting
flake8 app/
mypy app/

# Start development server (outside Docker)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Backend Architecture**:
- **API Structure**: `/api/v1/endpoints/` for route handlers
- **Authentication**: JWT tokens with role-based access
- **Protected Routes**: Airflow endpoints require `is_airflow_admin = true`
- **Business Logic**: Separated into `services/` layer
- **Database**: SQLAlchemy ORM with Pydantic validation

### DBT Development

```bash
# Access DBT container
docker-compose exec dbt bash

# Install dependencies
dbt deps

# Run specific model layers
dbt run --models staging
dbt run --models intermediate
dbt run --models marts

# Test data quality
dbt test

# Generate documentation
dbt docs generate && dbt docs serve
```

**Adding New DBT Models**:

1. Create SQL file in appropriate `dbt_project/models/` subdirectory
2. Use the `{{ postgres_scan('table_name') }}` macro for PostgreSQL access
3. Test: `dbt run --models your_model_name`
4. Add tests in corresponding schema.yml file

**Important DBT Patterns**:
- Always use `{{ postgres_scan('table') }}` macro, not direct connection strings
- Extract days from intervals: `EXTRACT(DAY FROM interval_column)`
- DuckDB extensions loaded in `on-run-start` hooks

### Database Extensions

The project automatically loads required DuckDB extensions:
- `postgres_scanner`: For cross-database queries from PostgreSQL
- `httpfs`: For remote file access

## Data Volume Management

**DuckDB Volume Architecture**:

The `duckdb_data` **Docker volume** (not a bind mount) is shared between containers:
- `duckdb_init`: Creates `/data/hirewire.duckdb` on first run
- `dbt`: Reads/writes via `/data/hirewire.duckdb` during transformations
- `airflow-*`: Accesses via `/data/hirewire.duckdb` for verification tasks
- `superset`: Reads via `/duckdb-data/hirewire.duckdb` (read-only)

**Why Docker Volume?**
- Consistent permissions across containers (no macOS/Linux permission issues)
- Better performance (Docker-optimized storage)
- Shared state between Airflow workers, DBT, and verification scripts
- Requires `docker cp` or helper script to access file from local system

## Environment Configuration

Create a `.env` file in the project root with the following variables:

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=hirewire

# Backend API
SECRET_KEY=your-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30
BACKEND_API_URL=http://backend:8000

# Airflow
AIRFLOW_USERNAME=admin
AIRFLOW_PASSWORD=admin
AIRFLOW_POSTGRES_PASSWORD=airflow
AIRFLOW_FERNET_KEY=46BKJoQYlPPOexq0OhDZnIlNepKFf87WFwLbfzqDDho=

# SMTP (for export emails)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM=noreply@hirewire.com
```

See `.env.example` for complete configuration options.

## Troubleshooting

### Common Issues

**DuckDB Permissions**:
- Ensure `duckdb_data` volume is writable across containers
- If issues persist, recreate volume: `docker-compose down -v && docker-compose up -d`

**DBT Model Dependencies**:
- Always run `dbt deps` after pulling changes to install dependencies
- Check extensions loaded: `INSTALL postgres_scanner; LOAD postgres_scanner;`

**Airflow DAGs Not Appearing**:
```bash
# Check import errors
docker exec hirewire_airflow_scheduler airflow dags list-import-errors

# Force DAG discovery
docker exec hirewire_airflow_scheduler airflow dags reserialize

# Unpause DAGs
docker exec hirewire_airflow_postgres psql -U airflow -d airflow -c \
  "UPDATE dag SET is_paused = false;"
```

**Airflow Access Denied (403)**:
- Ensure user is logged in via React app (http://localhost:5173)
- Verify `is_airflow_admin = true` in database:
  ```sql
  SELECT email, is_airflow_admin FROM hirewire.users WHERE email = 'your@email.com';
  ```
- Check JWT token is valid (login again if expired)

**Export Email Not Received**:
- Check spam/junk folder
- Verify SMTP credentials in `.env`
- Test SMTP connection:
  ```bash
  docker-compose exec airflow-worker python -c "
  import smtplib
  server = smtplib.SMTP('smtp.gmail.com', 587)
  server.starttls()
  server.login('user@gmail.com', 'password')
  print('SMTP OK')
  "
  ```
- For Gmail: Use App Password (not account password)
- Check Airflow logs: `docker-compose logs airflow-worker | grep -A 20 "send_email"`

**PostgreSQL Connection Issues**:
- Use `postgres` as hostname in container network
- Use `localhost` when connecting from host machine
- Check credentials in `.env` match `docker-compose.yml`

**Frontend API Calls Failing**:
- Verify backend is running: `curl http://localhost:8000/health`
- Check CORS settings in `backend/app/core/config.py`
- Inspect browser console for detailed error messages
- Verify JWT token is valid (re-login if expired)

**Superset DuckDB Connection**:
- Use SQLAlchemy URI: `duckdb:////duckdb-data/hirewire.duckdb`
- DuckDB driver is pre-installed in custom Docker image
- Ensure Superset is started with `--profile superset`

### Logs and Monitoring

**View Service Logs**:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f airflow-scheduler
docker-compose logs -f dbt

# Last 50 lines
docker-compose logs --tail 50 backend
```

**ETL Audit Logs**:
- Legacy scripts create logs in `scripts/logs/etl_audit.log`
- Airflow DAG logs available in UI at http://localhost:8081

**Database Monitoring**:
```sql
-- Active processes
SELECT COUNT(*) FROM hirewire.interview_processes WHERE status != 'closed';

-- Recent interviews
SELECT * FROM hirewire.interviews ORDER BY scheduled_date DESC LIMIT 5;

-- Export status
SELECT id, status, created_at, completed_at FROM hirewire.exports ORDER BY created_at DESC LIMIT 10;
```

## Shutdown

```bash
# Stop all services
docker-compose down

# Stop Airflow services only
docker-compose --profile airflow down

# Stop and remove all data volumes (WARNING: deletes all data)
docker-compose down -v
```

## Tech Highlights

**Modern Best Practices**:
- Docker multi-stage builds for optimized images
- Docker volumes for shared state (not bind mounts) for cross-platform compatibility
- Nginx reverse proxy for Airflow authentication
- JWT-based role-based access control

**Airflow 3 Architecture**:
- Separate DAG processor for faster parsing
- Celery executor for parallel task execution
- BashOperator with `docker exec` (avoids DockerOperator mount issues)
- API-first pattern: DAGs call backend endpoints for business logic

**DBT Best Practices**:
- Custom `postgres_scan()` macro for cross-database queries
- Three-layer architecture: staging → intermediate → marts
- Data quality tests with schema validation
- Automatic documentation generation

**Frontend Performance**:
- TanStack Query for intelligent caching and background updates
- Optimistic UI updates for instant feedback
- Side panels instead of full-page navigation
- Lazy loading for large datasets

## Contributing

This is a personal project, but suggestions and feedback are welcome. Please open an issue to discuss potential changes.

## License

MIT License - See LICENSE file for details

---

**Built with**: React, TypeScript, FastAPI, PostgreSQL, DuckDB, DBT, Apache Airflow 3, Apache Superset, Docker, Nginx