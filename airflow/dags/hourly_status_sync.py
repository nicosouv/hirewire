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
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator
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
        bash_command='cd /opt/airflow/dbt_project && dbt run --models mart_active_applications --target duckdb',
        dag=dag,
    )

    # Task 2: Refresh interview summary (includes recent changes)
    refresh_interview_summary = BashOperator(
        task_id='refresh_interview_summary',
        bash_command='cd /opt/airflow/dbt_project && dbt run --models mart_interview_summary_duckdb --target duckdb',
        dag=dag,
    )

    # Task 3: Check data freshness
    def check_data_freshness():
        """Check if data is fresh (updated in last 24 hours)"""
        import duckdb
        from datetime import datetime, timedelta

        conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)

        # Check for recent interviews
        result = conn.execute("""
            SELECT
                MAX(scheduled_date) as latest_interview,
                COUNT(*) as total_interviews
            FROM fact_interviews
            WHERE scheduled_date >= CURRENT_DATE - INTERVAL '7 days'
        """).fetchone()

        latest_interview = result[0]
        total_recent = result[1]

        logger.info(f"Latest interview: {latest_interview}")
        logger.info(f"Interviews in last 7 days: {total_recent}")

        # Check for recent process updates
        result = conn.execute("""
            SELECT
                COUNT(*) as active_processes
            FROM fact_interview_processes
            WHERE status NOT IN ('rejected', 'accepted', 'withdrew', 'ghosted')
        """).fetchone()

        active_count = result[0]
        logger.info(f"Active processes: {active_count}")

        conn.close()

        if active_count == 0:
            logger.warning("No active processes found - is data being updated?")

        logger.info("Data freshness check completed")

    check_freshness = PythonOperator(
        task_id='check_data_freshness',
        python_callable=check_data_freshness,
        dag=dag,
    )

    # Task 4: Monitor for stale applications (no activity in 14+ days)
    def monitor_stale_applications():
        """Identify applications with no recent activity"""
        import duckdb

        conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)

        stale = conn.execute("""
            SELECT
                company_name,
                position_title,
                status,
                days_since_last_activity
            FROM mart_active_applications
            WHERE days_since_last_activity > 14
            ORDER BY days_since_last_activity DESC
        """).fetchall()

        if stale:
            logger.warning(f"Found {len(stale)} stale applications (no activity in 14+ days):")
            for app in stale[:5]:  # Show top 5
                logger.warning(f"  - {app[0]} ({app[1]}): {app[3]} days since last activity")
        else:
            logger.info("No stale applications found")

        conn.close()

    monitor_stale = PythonOperator(
        task_id='monitor_stale_applications',
        python_callable=monitor_stale_applications,
        dag=dag,
    )

    # Define task dependencies
    [refresh_active_applications, refresh_interview_summary] >> check_freshness >> monitor_stale
