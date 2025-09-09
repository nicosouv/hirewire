FROM apache/superset:4.1.4

# Switch to root to install packages
USER root

# Install DuckDB driver for Python/SQLAlchemy
RUN pip install --no-cache-dir duckdb-engine

# Install additional useful packages
RUN pip install --no-cache-dir \
    psycopg2-binary \
    redis

# Create directory for DuckDB files
RUN mkdir -p /app/duckdb-data && chown -R superset:superset /app/duckdb-data

# Switch back to superset user
USER superset

# Copy superset config
COPY .infra/docker/superset_config.py /app/pythonpath/superset_config.py

# Set environment variables
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py
ENV PYTHONPATH=/app/pythonpath:$PYTHONPATH