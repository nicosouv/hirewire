FROM apache/superset:4.1.4

# Switch to root to install packages
USER root

# Install DuckDB driver for Python/SQLAlchemy and PostgreSQL client
RUN pip install --no-cache-dir duckdb-engine
RUN pip install --no-cache-dir \
    psycopg2-binary \
    redis

# Install PostgreSQL client for pg_isready
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /app/duckdb-data /app/scripts && chown -R superset:superset /app/duckdb-data /app/scripts

# Copy initialization script
#COPY .infra/docker/superset_init.sh /app/scripts/init.sh
#RUN chmod +x /app/scripts/init.sh

# Copy superset config
COPY .infra/docker/superset_config.py /app/pythonpath/superset_config.py

# Copy HireWire dashboards (will be created by build process)
#COPY .infra/docker/hirewire_dashboards.zip /app/hirewire_dashboards.zip

# Switch back to superset user
USER superset

# Set environment variables
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py
ENV PYTHONPATH=/app/pythonpath:$PYTHONPATH

# Default command runs initialization then starts superset
#CMD ["/bin/bash", "-c", "/app/scripts/init.sh && superset run -p 8088 --with-threads --reload --debugger --host=0.0.0.0"]