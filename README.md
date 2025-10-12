![HireWire](https://github.com/nicosouv/hirewire/blob/main/frontend/public/logo.png?raw=true)

# Interview Analytics Platform

A modern data analytics platform to track and analyze my job interview processes. Built with PostgreSQL for transactional data, DBT for transformations, DuckDB for analytics, and Apache Superset for dashboards.

## Architecture

This project uses a dual-database architecture optimized for both transactional and analytical workloads:

- **React + TypeScript Frontend**: Modern web UI with Kanban board, side panels, and smart priority actions
- **FastAPI Backend**: REST API with JWT authentication and business logic
- **PostgreSQL**: Primary database for raw interview data and transactional operations
- **DBT**: Data transformation layer that orchestrates PostgreSQL → DuckDB pipeline
- **DuckDB**: Columnar analytics database with star schema for fast queries
- **Apache Superset**: Modern dashboarding and visualization platform
- **Apache Airflow**: Orchestration platform for automated ETL workflows

## Why This Stack?

I chose this architecture because:
- PostgreSQL handles transactional data reliably
- DuckDB excels at analytical queries on interview data
- DBT provides clean data modeling and documentation
- Superset offers better visualization capabilities than Metabase for my use case

## Project Structure

```
hirewire/
├── docker-compose.yml           # Service orchestration
├── sql/
│   ├── postgres/               # PostgreSQL schemas (raw data)
│   └── duckdb/                 # DuckDB star schema + ETL views
├── dbt_project/
│   ├── models/
│   │   ├── staging/            # Extract from PostgreSQL
│   │   ├── intermediate/       # Business logic transformations
│   │   └── marts/              # Analytics-ready tables
│   └── macros/                 # Custom DBT macros
├── scripts/
│   ├── data_entry/             # Interactive data entry scripts
│   ├── etl/                    # ETL automation scripts
│   └── main.sh                 # Central script manager
└── profiles/                   # DBT connection configs
```

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git

### Setup

1. **Start all services**
```bash
docker-compose up -d --build
```

2. **Run the complete ETL pipeline**
```bash
./scripts/etl_runner.sh
```

3. **Test the setup**
```bash
./scripts/test_setup.sh
```

### Available Services

- **Web Application**: http://localhost:5173 (React UI with Kanban board)
- **Backend API**: http://localhost:8000 (FastAPI with Swagger docs at /docs)
- **PostgreSQL**: `localhost:5432` (postgres/password/hirewire)
- **Apache Airflow**: http://localhost:8081 (secured via JWT, requires is_airflow_admin)
- **Apache Superset**: http://localhost:8088 (admin/admin, requires `--profile superset`)
- **DuckDB**: File-based at `/data/hirewire.duckdb`

### Default Login Credentials

**Web Application**:
- Email: `admin@hirewire.com`
- Password: `secret`

**Airflow Access**:
- Login via web app first, then access http://localhost:8081
- Requires `is_airflow_admin = true` in database

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

## ETL Automation

The platform includes several automated ETL processes:

### Available ETL Commands
```bash
./scripts/main.sh etl run                    # Complete ETL pipeline
./scripts/main.sh etl update-interviews      # Mark past scheduled interviews as completed
./scripts/main.sh etl update-status         # Update process status based on interview activity
./scripts/main.sh etl sync-all              # Comprehensive status synchronization
./scripts/main.sh etl detect-ghosted        # Auto-detect abandoned processes
```

### Smart Status Updates

The platform automatically:
- Progresses process status: `applied` → `screening` → `interviewing` → `final_round`
- Detects ghosted processes (no response after extended periods)
- Syncs process status with final outcomes
- Updates past scheduled interviews to completed

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

## Database Access

### PostgreSQL (Raw Data)
```bash
docker-compose exec postgres psql -U postgres -d hirewire
```

### DuckDB (Analytics)
```bash
docker-compose exec dbt python -c "
import duckdb
conn = duckdb.connect('/data/hirewire.duckdb')
result = conn.execute('SELECT * FROM mart_active_applications').fetchall()
for row in result: print(row)
"
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

### Adding New Models

1. Create SQL file in appropriate `dbt_project/models/` subdirectory
2. Use the `{{ postgres_scan('table_name') }}` macro for PostgreSQL access
3. Test: `dbt run --models your_model_name`
4. Add tests in corresponding schema.yml file

### Database Extensions

The project automatically loads required DuckDB extensions:
- `postgres_scanner`: For cross-database queries
- `httpfs`: For remote file access

## Data Volume Management

The `duckdb_data` Docker volume is shared between containers:
- `duckdb_init`: Creates initial database
- `dbt`: Reads/writes analytics models
- `superset`: Read-only access for dashboards

## Troubleshooting

### Common Issues

1. **DuckDB permissions**: Ensure volume is writable across containers
2. **DBT model dependencies**: Run `dbt deps` after pulling changes
3. **PostgreSQL connection**: Use `postgres` as hostname in container network
4. **Superset DuckDB driver**: Already included in custom Docker image

### Logs and Monitoring

ETL scripts create audit logs in `scripts/logs/etl_audit.log` for tracking automated changes.

## Shutdown

```bash
docker-compose down           # Stop services
docker-compose down -v        # Stop and remove data volumes
```

---