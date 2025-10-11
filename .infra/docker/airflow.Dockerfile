FROM apache/airflow:3.1.0-python3.13

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Add airflow user to docker group for Docker socket access
# The docker group on macOS typically has GID 999
RUN groupadd -g 999 docker || true && usermod -aG docker airflow

USER airflow

# Install Python packages for DBT, DuckDB, PostgreSQL, and Docker
# Using latest compatible versions with Airflow 3.1.0
RUN pip install --no-cache-dir \
    apache-airflow-providers-postgres==5.14.0 \
    apache-airflow-providers-celery==3.12.4 \
    apache-airflow-providers-docker==4.1.0 \
    dbt-core==1.10.10 \
    dbt-postgres==1.9.0 \
    dbt-duckdb==1.9.4 \
    duckdb==1.3.1 \
    psycopg2-binary==2.9.10 \
    pandas==2.2.3 \
    sqlalchemy==2.0.36 \
    requests==2.32.3

# Set Airflow home
ENV AIRFLOW_HOME=/opt/airflow

WORKDIR /opt/airflow
