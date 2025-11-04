"""
Recalculate User Gamification DAG

This DAG can be triggered manually or by other DAGs to recalculate
gamification data for a specific user.

Can be triggered with configuration:
- user_id: The user ID to recalculate (required)
- strategy: 'incremental' or 'full_reset' (optional, default: incremental)

Example trigger:
airflow dags trigger recalculate_user_gamification --conf '{"user_id": 1, "strategy": "full_reset"}'
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.exceptions import AirflowException
import requests
import json
import os

# Default arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': [os.getenv('SMTP_USER', 'admin@hirewire.com')],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=2),
}

# Create DAG
dag = DAG(
    'recalculate_user_gamification',
    default_args=default_args,
    description='Recalculate gamification data for a specific user',
    schedule=None,  # Manual trigger only
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['gamification', 'recalculation', 'manual', 'maintenance'],
    max_active_runs=5,  # Allow multiple concurrent runs for different users
)


def get_airflow_admin_token():
    """Get JWT token for Airflow admin user."""
    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')

    # Login credentials for Airflow system user
    response = requests.post(
        f"{backend_url}/api/v1/auth/login/json",
        json={
            "email": "airflow@hirewire.system",
            "password": os.getenv('AIRFLOW_SYSTEM_PASSWORD', 'airflow_secure_password_2025')
        }
    )
    response.raise_for_status()
    return response.json()['access_token']


def validate_configuration(**context):
    """
    Validate that the DAG was triggered with required configuration.
    """
    dag_run = context['dag_run']
    conf = dag_run.conf or {}

    user_id = conf.get('user_id')
    strategy = conf.get('strategy', 'incremental')

    if not user_id:
        raise AirflowException(
            "Configuration error: 'user_id' is required. "
            "Trigger with: airflow dags trigger recalculate_user_gamification "
            "--conf '{\"user_id\": 1, \"strategy\": \"incremental\"}'"
        )

    if strategy not in ['incremental', 'full_reset']:
        raise AirflowException(
            f"Configuration error: 'strategy' must be 'incremental' or 'full_reset', got '{strategy}'"
        )

    print(f"✓ Configuration valid: user_id={user_id}, strategy={strategy}")

    # Store in XCom for other tasks
    context['task_instance'].xcom_push(key='user_id', value=user_id)
    context['task_instance'].xcom_push(key='strategy', value=strategy)

    return {"user_id": user_id, "strategy": strategy}


def verify_user_before_recalc(**context):
    """
    Verify the user exists and check their current gamification state.
    """
    user_id = context['task_instance'].xcom_pull(task_ids='validate_config', key='user_id')
    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')
    token = get_airflow_admin_token()

    # Get current user stats
    try:
        response = requests.get(
            f"{backend_url}/api/v1/users/{user_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        response.raise_for_status()
        user = response.json()

        print(f"\n{'=' * 60}")
        print(f"User Information:")
        print(f"{'=' * 60}")
        print(f"User ID: {user_id}")
        print(f"Email: {user.get('email', 'N/A')}")
        print(f"{'=' * 60}")

        context['task_instance'].xcom_push(key='user_email', value=user.get('email', 'N/A'))

    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            raise AirflowException(f"User {user_id} not found")
        raise

    # Run verification to see what needs fixing
    try:
        verify_response = requests.post(
            f"{backend_url}/api/v1/airflow/tasks/verify-gamification",
            headers={"Authorization": f"Bearer {token}"}
        )
        verify_response.raise_for_status()
        verification = verify_response.json()

        # Find errors for this specific user
        user_errors = next(
            (u for u in verification.get('users_with_errors', []) if u['user_id'] == user_id),
            None
        )

        if user_errors:
            print(f"\n{'=' * 60}")
            print(f"Errors detected for user {user_id}:")
            print(f"{'=' * 60}")
            print(f"Error types: {', '.join(user_errors['error_types'])}")
            print(f"{'=' * 60}\n")
            context['task_instance'].xcom_push(key='has_errors', value=True)
            context['task_instance'].xcom_push(key='error_types', value=user_errors['error_types'])
        else:
            print(f"\n✓ No errors detected for user {user_id} - proceeding with recalculation anyway\n")
            context['task_instance'].xcom_push(key='has_errors', value=False)

    except Exception as e:
        print(f"Warning: Could not verify user before recalculation: {str(e)}")
        print("Proceeding with recalculation anyway...")


def recalculate_gamification(**context):
    """
    Perform the actual gamification recalculation.
    """
    user_id = context['task_instance'].xcom_pull(task_ids='validate_config', key='user_id')
    strategy = context['task_instance'].xcom_pull(task_ids='validate_config', key='strategy')
    user_email = context['task_instance'].xcom_pull(task_ids='verify_user', key='user_email')

    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')
    token = get_airflow_admin_token()

    print(f"\n{'=' * 80}")
    print(f"RECALCULATING GAMIFICATION DATA")
    print(f"{'=' * 80}")
    print(f"User ID: {user_id}")
    print(f"User Email: {user_email}")
    print(f"Strategy: {strategy}")
    print(f"{'=' * 80}\n")

    response = requests.post(
        f"{backend_url}/api/v1/airflow/tasks/recalculate-gamification/{user_id}?strategy={strategy}",
        headers={"Authorization": f"Bearer {token}"}
    )
    response.raise_for_status()

    result = response.json()

    # Display results
    print(f"\n{'=' * 80}")
    print(f"RECALCULATION COMPLETE")
    print(f"{'=' * 80}")
    print(f"User: {result['user_email']}")
    print(f"Strategy: {result['strategy']}")
    print(f"\nBefore:")
    for key, value in result['before'].items():
        print(f"  {key}: {value}")
    print(f"\nAfter:")
    for key, value in result['after'].items():
        print(f"  {key}: {value}")
    print(f"\nChanges:")
    for change in result['changes']:
        print(f"  - {change}")
    print(f"\nSummary:")
    print(f"  Points change: {result['changes_summary']['points_change']:+d}")
    print(f"  Level change: {result['changes_summary']['level_change']:+d}")
    print(f"  Achievements change: {result['changes_summary']['achievements_change']:+d}")
    print(f"{'=' * 80}\n")

    # Store results in XCom
    context['task_instance'].xcom_push(key='result', value=result)

    return result


def verify_after_recalc(**context):
    """
    Verify the recalculation was successful by running verification again.
    """
    user_id = context['task_instance'].xcom_pull(task_ids='validate_config', key='user_id')
    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')
    token = get_airflow_admin_token()

    print(f"\n{'=' * 60}")
    print(f"POST-RECALCULATION VERIFICATION")
    print(f"{'=' * 60}\n")

    # Run verification
    verify_response = requests.post(
        f"{backend_url}/api/v1/airflow/tasks/verify-gamification",
        headers={"Authorization": f"Bearer {token}"}
    )
    verify_response.raise_for_status()
    verification = verify_response.json()

    # Check if user still has errors
    user_errors = next(
        (u for u in verification.get('users_with_errors', []) if u['user_id'] == user_id),
        None
    )

    if user_errors:
        print(f"⚠ Warning: User {user_id} still has errors after recalculation:")
        print(f"Error types: {', '.join(user_errors['error_types'])}")
        print("This may require manual intervention or a full_reset strategy.\n")
        context['task_instance'].xcom_push(key='verification_passed', value=False)
        return False
    else:
        print(f"✓ Success: User {user_id} has no errors after recalculation\n")
        context['task_instance'].xcom_push(key='verification_passed', value=True)
        return True


def send_success_notification(**context):
    """
    Send notification on successful recalculation.
    """
    user_id = context['task_instance'].xcom_pull(task_ids='validate_config', key='user_id')
    user_email = context['task_instance'].xcom_pull(task_ids='verify_user', key='user_email')
    result = context['task_instance'].xcom_pull(task_ids='recalculate', key='result')
    verification_passed = context['task_instance'].xcom_pull(task_ids='verify_after', key='verification_passed')

    print(f"\n{'=' * 80}")
    print(f"NOTIFICATION: Gamification Recalculation Complete")
    print(f"{'=' * 80}")
    print(f"User: {user_email} (ID: {user_id})")
    print(f"Verification: {'✓ PASSED' if verification_passed else '⚠ FAILED'}")
    print(f"Changes: {result['changes_summary']}")
    print(f"{'=' * 80}\n")


# Task 1: Validate configuration
validate_config = PythonOperator(
    task_id='validate_config',
    python_callable=validate_configuration,
    dag=dag,
)

# Task 2: Verify user exists and check current state
verify_user = PythonOperator(
    task_id='verify_user',
    python_callable=verify_user_before_recalc,
    dag=dag,
)

# Task 3: Perform recalculation
recalculate = PythonOperator(
    task_id='recalculate',
    python_callable=recalculate_gamification,
    dag=dag,
)

# Task 4: Verify recalculation was successful
verify_after = PythonOperator(
    task_id='verify_after',
    python_callable=verify_after_recalc,
    dag=dag,
)

# Task 5: Send notification
send_notification = PythonOperator(
    task_id='send_notification',
    python_callable=send_success_notification,
    dag=dag,
)

# Define task dependencies
validate_config >> verify_user >> recalculate >> verify_after >> send_notification
