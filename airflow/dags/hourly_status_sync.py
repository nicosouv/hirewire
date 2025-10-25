"""
Hourly Status Sync DAG

This DAG runs lightweight incremental updates every hour:
1. Sync only changed records from PostgreSQL
2. Update active application marts
3. Monitor data freshness

Runs hourly during business hours (9 AM - 7 PM Paris time, Monday-Friday)
"""

from datetime import datetime, timedelta
from airflow.models.dag import DAG
from airflow.operators.bash import BashOperator
import logging

logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'hirewire',
    'depends_on_past': False,
    'email_on_failure': False,  # Disabled to avoid DB column size issues
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
    'execution_timeout': timedelta(minutes=10),
}

# Define the DAG
with DAG(
    dag_id='hourly_status_sync',
    default_args=default_args,
    description='Hourly sync for active applications and recent changes',
    schedule='0 9-19 * * 1-5',  # Every hour from 9 AM to 7 PM, Monday-Friday
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['etl', 'incremental', 'hourly'],
    max_active_runs=1,
) as dag:

    # Task 1: Quick refresh of active applications mart
    refresh_active_applications = BashOperator(
        task_id='refresh_active_applications',
        bash_command='docker exec hirewire_dbt dbt run --models mart_active_applications --target duckdb',
        dag=dag,
    )

    # Task 2: Refresh interview summary (includes recent changes)
    refresh_interview_summary = BashOperator(
        task_id='refresh_interview_summary',
        bash_command='docker exec hirewire_dbt dbt run --models mart_interview_summary_duckdb --target duckdb',
        dag=dag,
    )

    # Task 3: Check data freshness using script in dbt container
    check_freshness = BashOperator(
        task_id='check_data_freshness',
        bash_command='docker exec hirewire_dbt python /scripts/airflow/check_data_freshness.py',
        dag=dag,
    )

    # Task 4: Monitor for stale applications using script in dbt container
    monitor_stale = BashOperator(
        task_id='monitor_stale_applications',
        bash_command='docker exec hirewire_dbt python /scripts/airflow/monitor_stale_applications.py',
        dag=dag,
    )

    # Define task dependencies
    [refresh_active_applications, refresh_interview_summary] >> check_freshness >> monitor_stale
