"""
Update Past Interviews DAG

This DAG automatically updates interviews that are:
- Status = 'scheduled'
- scheduled_date < current timestamp
→ Changes their status to 'completed'

Runs every 6 hours to keep interview statuses up to date.
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

def update_past_scheduled_interviews():
    """
    Update interviews from 'scheduled' to 'completed' when their scheduled_date has passed.
    Calls the HireWire API endpoint for this operation.
    """
    # Get API configuration from Airflow variables
    api_url = Variable.get("HIREWIRE_API_URL", default_var="http://api:8000")
    api_token = Variable.get("HIREWIRE_API_TOKEN")

    endpoint = f"{api_url}/api/v1/airflow/tasks/update-past-interviews"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }

    try:
        logger.info(f"Calling API endpoint: {endpoint}")
        response = requests.post(endpoint, headers=headers, timeout=30)
        response.raise_for_status()

        result = response.json()

        # Log results
        logger.info(f"✅ {result['message']}")
        logger.info(f"Updated {result['updated_count']} interviews")

        if result['interviews']:
            logger.info("Interviews updated:")
            for interview in result['interviews']:
                logger.info(
                    f"  - ID {interview['id']}: {interview['company_name']} - "
                    f"{interview['position_title']} ({interview['interview_type']}) - "
                    f"{interview['days_past']} days past"
                )

        # Log statistics
        stats = result['stats']
        logger.info(
            f"Interview status summary: Total={stats['total']}, "
            f"Scheduled={stats['scheduled']}, Completed={stats['completed']}, "
            f"Cancelled={stats['cancelled']}"
        )

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
    dag_id='update_past_interviews',
    default_args=default_args,
    description='Update past scheduled interviews to completed status',
    schedule='0 */6 * * *',  # Run every 6 hours (00:00, 06:00, 12:00, 18:00)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['etl', 'interviews', 'maintenance'],
    max_active_runs=1,
) as dag:

    update_task = PythonOperator(
        task_id='update_past_interviews',
        python_callable=update_past_scheduled_interviews,
        dag=dag,
    )
