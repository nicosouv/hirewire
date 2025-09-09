#!/bin/bash
# DuckDB Initialization Script (DBT-only architecture)

set -e

DUCKDB_PATH="/data/hirewire.duckdb"

echo "🦆 Initializing DuckDB..."

# Check if DuckDB file already exists
if [ -f "$DUCKDB_PATH" ]; then
    echo "✅ DuckDB database already exists at $DUCKDB_PATH"
    echo "📊 Database info:"
    python3 -c "
import duckdb
conn = duckdb.connect('$DUCKDB_PATH')
result = conn.execute('SELECT count(*) as table_count FROM duckdb_tables()').fetchone()
print(f'Tables: {result[0]}')
conn.close()
"
    # Copy to local directory if not exists
    if [ ! -f "/data-local/hirewire.duckdb" ]; then
        cp "$DUCKDB_PATH" "/data-local/hirewire.duckdb"
        echo "🔗 Local access available at: ./data/hirewire.duckdb"
    fi
    exit 0
fi

echo "🔧 Creating new empty DuckDB database..."

# Create empty database - DBT will handle all schema creation
python3 -c "
import duckdb
conn = duckdb.connect('$DUCKDB_PATH')

# Install required extensions for DBT
conn.execute('INSTALL httpfs')
conn.execute('LOAD httpfs')
conn.execute('INSTALL postgres_scanner')  
conn.execute('LOAD postgres_scanner')
conn.execute('INSTALL icu')
conn.execute('LOAD icu')

print('✅ Empty DuckDB database created')
print('🔌 Extensions installed: httpfs, postgres_scanner, icu')
print('📋 DBT will handle all schema and data creation')

conn.close()
"

echo "✅ DuckDB initialization complete!"
echo "📍 Database location: $DUCKDB_PATH"

# Copy to local bind mount for external access
echo "📂 Copying DuckDB file to local directory..."
cp "$DUCKDB_PATH" "/data-local/hirewire.duckdb"
echo "🔗 Local access available at: ./data/hirewire.duckdb"
echo ""
echo "🚀 Next steps:"
echo "  1. Run: ./scripts/main.sh etl run"
echo "  2. DBT will create staging → intermediate → marts"