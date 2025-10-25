"""
Update Process Status DAG

This DAG automatically updates interview process statuses based on interview activity.

Intelligent status transitions:
- applied → screening (when screening interview scheduled)
- applied/screening → interviewing (when technical interviews or 2+ completed)
- interviewing → final_round (when final interview or 3+ completed)

Also identifies stale processes that may need manual review.

Runs daily at 3 AM Paris time to keep process statuses synchronized with interview progress.
Uses the HireWire API instead of direct database queries.
"""

from datetime import datetime, timedelta
from airflow.models.dag import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.models import Variable
import logging
import requests

logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'hirewire',
    'depends_on_past': False,
    'email_on_failure': False,  # Disabled to avoid DB column size issues
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}


def update_process_status_task():
    """
    Update process statuses based on interview activity.
    Calls the HireWire API endpoint for this operation.
    """
    # Get API configuration from Airflow variables
    api_url = Variable.get("HIREWIRE_API_URL", default_var="http://api:8000")
    api_token = Variable.get("HIREWIRE_API_TOKEN")

    endpoint = f"{api_url}/api/v1/airflow/tasks/update-process-status"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }

    try:
        logger.info(f"Calling API endpoint: {endpoint}")
        response = requests.post(endpoint, headers=headers, timeout=60)
        response.raise_for_status()

        result = response.json()

        # Log main message
        logger.info(f"✅ {result['message']}")
        logger.info(f"Total updates: {result['total_updates']}")

        # Log status transitions
        if result['updates']:
            logger.info("\nStatus transitions:")
            for update in result['updates']:
                logger.info(f"  - {update['transition']}: {update['count']} processes")
                logger.info(f"    Process IDs: {update['process_ids']}")

        # Log statistics
        logger.info("\nProcess status distribution:")
        logger.info(f"  Before: Total={result['stats_before']['total']}")
        for status, count in result['stats_before']['by_status'].items():
            logger.info(f"    {status}: {count}")

        logger.info(f"  After: Total={result['stats_after']['total']}")
        for status, count in result['stats_after']['by_status'].items():
            logger.info(f"    {status}: {count}")

        # Log stale processes
        if result['stale_count'] > 0:
            logger.warning(f"\n⚠️  Found {result['stale_count']} stale processes needing manual review:")
            for process in result['stale_processes']:
                logger.warning(
                    f"  - {process['company']} ({process['position']}): "
                    f"status={process['status']}, "
                    f"days_since_application={process['days_since_application']}, "
                    f"days_since_last_interview={process['days_since_last_interview']}"
                )
        else:
            logger.info("\n✅ No stale processes found")

    except requests.exceptions.HTTPError as e:
        logger.error(f"❌ API request failed with status {e.response.status_code}: {e.response.text}")
        raise
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Error calling API: {e}")
        raise
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
        raise


# Define the DAG
with DAG(
    dag_id='update_process_status',
    default_args=default_args,
    description='Automatically update process statuses based on interview activity',
    schedule='0 9-19 * * 1-5',  # Every hour from 9 AM to 7 PM, Monday-Friday
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['etl', 'processes', 'maintenance'],
    max_active_runs=1,
) as dag:

    update_task = PythonOperator(
        task_id='update_process_status',
        python_callable=update_process_status_task,
        dag=dag,
    )
