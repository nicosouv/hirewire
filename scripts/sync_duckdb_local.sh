#!/bin/bash
#
# Sync DuckDB file from Docker volume to local filesystem
#
# Usage: ./scripts/sync_duckdb_local.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📦 Copying DuckDB file from Docker volume to local filesystem..."

# Copy from dbt container (which has the duckdb_data volume mounted)
docker cp hirewire_dbt:/data/hirewire.duckdb "$PROJECT_ROOT/data/hirewire.duckdb"

if [ $? -eq 0 ]; then
    echo "✅ DuckDB file synced successfully!"
    ls -lh "$PROJECT_ROOT/data/hirewire.duckdb"

    echo ""
    echo "📊 Quick stats:"
    docker exec hirewire_dbt python -c "
import duckdb
conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)
tables = conn.execute(\"SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' AND table_name LIKE 'mart_%' ORDER BY table_name\").fetchall()
print(f'  Mart tables: {len(tables)}')
interviews = conn.execute('SELECT COUNT(*) FROM int_interviews').fetchone()[0]
print(f'  Total interviews: {interviews}')
processes = conn.execute('SELECT COUNT(*) FROM int_interview_processes').fetchone()[0]
print(f'  Total processes: {processes}')
conn.close()
"
else
    echo "❌ Failed to sync DuckDB file"
    exit 1
fi
