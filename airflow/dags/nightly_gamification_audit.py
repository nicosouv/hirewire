"""
Nightly Gamification Audit DAG

This DAG runs every night at 3 AM to verify gamification data integrity
for all users. If errors are detected, it triggers the recalculation DAG
for affected users.

Schedule: Daily at 3 AM Paris time (Europe/Paris)
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.utils.trigger_rule import TriggerRule
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
    'retry_delay': timedelta(minutes=5),
}

# Create DAG
dag = DAG(
    'nightly_gamification_audit',
    default_args=default_args,
    description='Verify gamification data integrity for all users',
    schedule='0 3 * * *',  # Every day at 3 AM
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['gamification', 'audit', 'nightly', 'maintenance'],
    max_active_runs=1,
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


def verify_gamification(**context):
    """
    Call the verification endpoint and return results.
    """
    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')
    token = get_airflow_admin_token()

    response = requests.post(
        f"{backend_url}/api/v1/airflow/tasks/verify-gamification",
        headers={"Authorization": f"Bearer {token}"}
    )
    response.raise_for_status()

    result = response.json()

    # Print summary
    print("=" * 80)
    print("GAMIFICATION AUDIT RESULTS")
    print("=" * 80)
    print(f"Total users checked: {result['total_users_checked']}")
    print(f"Users with errors: {result['users_with_errors_count']}")
    print(f"Total errors found: {result['total_errors_found']}")
    print("\nError breakdown:")
    print(f"  - Counter errors: {result['error_summary']['counter_errors']}")
    print(f"  - Missing achievements: {result['error_summary']['missing_achievements']}")
    print(f"  - Point errors: {result['error_summary']['point_errors']}")
    print(f"  - Level errors: {result['error_summary']['level_errors']}")
    print("=" * 80)

    # Store users to fix in XCom
    context['task_instance'].xcom_push(key='users_to_fix', value=result['users_to_fix'])
    context['task_instance'].xcom_push(key='error_details', value=result['error_details'])
    context['task_instance'].xcom_push(key='total_errors', value=result['total_errors_found'])

    return result


def decide_if_fixes_needed(**context):
    """
    Check if there are users that need fixing.
    Returns True if fixes are needed, False otherwise.
    """
    users_to_fix = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='users_to_fix')
    total_errors = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='total_errors')

    if users_to_fix and len(users_to_fix) > 0:
        print(f"✗ Found {len(users_to_fix)} users with {total_errors} errors - triggering recalculation DAGs")
        return True
    else:
        print("✓ No errors found - all gamification data is consistent")
        return False


def trigger_recalculation_for_users(**context):
    """
    Trigger the recalculation DAG for each user that needs fixing.
    """
    users_to_fix = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='users_to_fix')
    error_details = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='error_details')

    if not users_to_fix:
        print("No users to fix")
        return

    backend_url = os.getenv('BACKEND_API_URL', 'http://backend:8000')
    token = get_airflow_admin_token()

    fixed_users = []
    failed_users = []

    for user_id in users_to_fix:
        # Determine strategy based on error types
        user_errors = next(
            (u for u in context['task_instance'].xcom_pull(task_ids='verify_gamification')['users_with_errors']
             if u['user_id'] == user_id),
            None
        )

        # Use full_reset if there are point errors or missing achievements
        # Otherwise use incremental
        strategy = "full_reset" if (
            user_errors and (
                'point_mismatch' in user_errors['error_types'] or
                'missing_achievements' in user_errors['error_types']
            )
        ) else "incremental"

        print(f"\n{'=' * 60}")
        print(f"Recalculating user {user_id} with strategy: {strategy}")
        print(f"{'=' * 60}")

        try:
            response = requests.post(
                f"{backend_url}/api/v1/airflow/tasks/recalculate-gamification/{user_id}?strategy={strategy}",
                headers={"Authorization": f"Bearer {token}"}
            )
            response.raise_for_status()

            result = response.json()

            print(f"✓ User {user_id} ({result['user_email']}) recalculated successfully")
            print(f"  Before: {result['before']}")
            print(f"  After: {result['after']}")
            print(f"  Changes: {', '.join(result['changes'])}")

            fixed_users.append({
                'user_id': user_id,
                'email': result['user_email'],
                'changes': result['changes_summary']
            })

        except Exception as e:
            print(f"✗ Failed to recalculate user {user_id}: {str(e)}")
            failed_users.append({'user_id': user_id, 'error': str(e)})

    # Summary
    print(f"\n{'=' * 60}")
    print(f"RECALCULATION SUMMARY")
    print(f"{'=' * 60}")
    print(f"Total users processed: {len(users_to_fix)}")
    print(f"Successfully fixed: {len(fixed_users)}")
    print(f"Failed: {len(failed_users)}")

    if failed_users:
        print("\nFailed users:")
        for user in failed_users:
            print(f"  - User {user['user_id']}: {user['error']}")

    # Store results for email notification
    context['task_instance'].xcom_push(key='fixed_users', value=fixed_users)
    context['task_instance'].xcom_push(key='failed_users', value=failed_users)


def send_email_notification(**context):
    """
    Send email notification with audit results.
    """
    total_errors = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='total_errors')
    fixed_users = context['task_instance'].xcom_pull(task_ids='trigger_recalculations', key='fixed_users') or []
    failed_users = context['task_instance'].xcom_pull(task_ids='trigger_recalculations', key='failed_users') or []
    error_details = context['task_instance'].xcom_pull(task_ids='verify_gamification', key='error_details')

    print("\n" + "=" * 80)
    print("EMAIL NOTIFICATION SUMMARY")
    print("=" * 80)
    print(f"\nTotal errors detected: {total_errors}")
    print(f"Users successfully fixed: {len(fixed_users)}")
    print(f"Users failed to fix: {len(failed_users)}")

    if error_details:
        print("\nError breakdown:")
        for error_type, errors in error_details.items():
            if errors:
                print(f"\n{error_type.replace('_', ' ').title()}: {len(errors)}")
                for error in errors[:3]:  # Show first 3
                    print(f"  - User {error.get('user_id', 'N/A')}: {error.get('email', 'N/A')}")

    if fixed_users:
        print("\nFixed users:")
        for user in fixed_users[:5]:  # Show first 5
            print(f"  - {user['email']}: {user['changes']}")

    if failed_users:
        print("\nFailed users (requires manual intervention):")
        for user in failed_users:
            print(f"  - User {user['user_id']}: {user['error']}")

    print("=" * 80)

    # In a real setup, you would use Airflow's EmailOperator here
    # For now, we just log the notification


# Task 1: Verify gamification data integrity
verify_task = PythonOperator(
    task_id='verify_gamification',
    python_callable=verify_gamification,
    dag=dag,
)

# Task 2: Check if fixes are needed
check_fixes_needed = PythonOperator(
    task_id='check_fixes_needed',
    python_callable=decide_if_fixes_needed,
    dag=dag,
)

# Task 3: Trigger recalculations for users with errors
trigger_recalculations = PythonOperator(
    task_id='trigger_recalculations',
    python_callable=trigger_recalculation_for_users,
    dag=dag,
)

# Task 4: Send email notification (runs even if no errors)
send_notification = PythonOperator(
    task_id='send_notification',
    python_callable=send_email_notification,
    trigger_rule=TriggerRule.ALL_DONE,  # Run even if previous tasks failed
    dag=dag,
)

# Task 5: Success message (only if no errors)
success_task = BashOperator(
    task_id='success_no_errors',
    bash_command='echo "✓ Gamification audit complete - no errors found"',
    trigger_rule=TriggerRule.ONE_SUCCESS,
    dag=dag,
)

# Define task dependencies
verify_task >> check_fixes_needed
check_fixes_needed >> trigger_recalculations >> send_notification
check_fixes_needed >> success_task >> send_notification
