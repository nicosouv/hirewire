FROM ghcr.io/dbt-labs/dbt-core:1.11.2

# Install additional DBT adapters
RUN pip install \
    duckdb==1.3.1 \
    dbt-postgres==1.9.0 \
    dbt-duckdb==1.9.4 \
    psycopg2-binary==2.9.11

# Install system dependencies for DuckDB CLI
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# DuckDB CLI is already included in duckdb package
# No additional installation needed

WORKDIR /usr/app/dbt