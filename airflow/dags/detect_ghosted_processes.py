"""
Detect Ghosted Processes DAG

This DAG automatically detects and marks processes as "ghosted" based on inactivity patterns.

Ghosting criteria:
- No response after 60+ days with no interviews
- Had interviews but no follow-up for 45+ days
- Applied status for 30+ days with no interviews

When a process is detected as ghosted, it:
1. Updates process status to 'ghosted'
2. Creates a 'ghosted' outcome automatically
3. Excludes it from active applications

Runs daily at 4 AM Paris time to detect ghosting patterns.
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


def detect_ghosted_processes_task():
    """
    Detect and mark ghosted processes based on inactivity.
    Calls the HireWire API endpoint for this operation.
    """
    # Get API configuration from Airflow variables
    api_url = Variable.get("HIREWIRE_API_URL", default_var="http://api:8000")
    api_token = Variable.get("HIREWIRE_API_TOKEN")

    endpoint = f"{api_url}/api/v1/airflow/tasks/detect-ghosted-processes"
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
        logger.info(f"Ghosted count: {result['ghosted_count']}")

        # Log ghosted processes details
        if result['ghosted_count'] > 0:
            logger.warning(f"\n👻 Detected {result['ghosted_count']} ghosted processes:")
            for process in result['ghosted_processes']:
                logger.warning(
                    f"  - {process['company']} ({process['position']}): "
                    f"{process['ghosting_reason']} - "
                    f"applied {process['days_since_application']} days ago"
                )
                if process['total_interviews'] > 0:
                    logger.warning(
                        f"    Had {process['total_interviews']} interviews, "
                        f"last one {process['days_since_last_interview']} days ago"
                    )
        else:
            logger.info("✅ No ghosted processes detected")

        # Log statistics
        logger.info("\nProcess status distribution:")
        logger.info(f"  Before: Total={result['stats_before']['total']}")
        for status, count in result['stats_before']['by_status'].items():
            logger.info(f"    {status}: {count}")

        logger.info(f"  After: Total={result['stats_after']['total']}")
        for status, count in result['stats_after']['by_status'].items():
            logger.info(f"    {status}: {count}")

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
    dag_id='detect_ghosted_processes',
    default_args=default_args,
    description='Auto-detect and mark ghosted processes based on inactivity',
    schedule='0 4 * * *',  # Run daily at 4 AM Paris time
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['etl', 'processes', 'ghosting', 'maintenance'],
    max_active_runs=1,
) as dag:

    detect_task = PythonOperator(
        task_id='detect_ghosted_processes',
        python_callable=detect_ghosted_processes_task,
        dag=dag,
    )
