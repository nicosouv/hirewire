"""
Update Past Interviews DAG

This DAG automatically updates interviews that are:
- Status = 'scheduled'
- scheduled_date < current timestamp
→ Changes their status to 'completed'

Runs every 6 hours to keep interview statuses up to date.
"""

from datetime import datetime, timedelta
from airflow.models.dag import DAG
from airflow.providers.standard.operators.python import PythonOperator
import logging

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
    """
    import psycopg2
    import os

    # Connection parameters
    conn_params = {
        'host': 'postgres',
        'port': 5432,
        'database': 'hirewire',
        'user': os.environ.get('POSTGRES_USER', 'postgres'),
        'password': os.environ.get('POSTGRES_PASSWORD', 'password')
    }

    try:
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()

        # Step 1: Check how many interviews need updating
        cur.execute("""
            SELECT COUNT(*)
            FROM hirewire.interviews
            WHERE scheduled_date < CURRENT_TIMESTAMP
              AND status = 'scheduled'
        """)
        count_to_update = cur.fetchone()[0]

        if count_to_update == 0:
            logger.info("✅ No past scheduled interviews to update. All up to date!")
            conn.close()
            return

        logger.info(f"Found {count_to_update} past scheduled interviews to update")

        # Step 2: Get details of interviews being updated (for logging)
        cur.execute("""
            SELECT
                i.id,
                c.name as company_name,
                jp.title as position_title,
                i.interview_type,
                i.scheduled_date,
                EXTRACT(DAY FROM (CURRENT_TIMESTAMP - i.scheduled_date)) as days_past
            FROM hirewire.interviews i
            JOIN hirewire.interview_processes ip ON i.process_id = ip.id
            JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
            JOIN hirewire.companies c ON jp.company_id = c.id
            WHERE i.scheduled_date < CURRENT_TIMESTAMP
              AND i.status = 'scheduled'
            ORDER BY i.scheduled_date
        """)

        interviews_to_update = cur.fetchall()
        logger.info(f"Interviews being updated:")
        for interview in interviews_to_update:
            interview_id, company, position, interview_type, scheduled_date, days_past = interview
            logger.info(f"  - ID {interview_id}: {company} - {position} ({interview_type}) - {int(days_past)} days past")

        # Step 3: Perform the update
        cur.execute("""
            UPDATE hirewire.interviews
            SET
                status = 'completed',
                updated_at = CURRENT_TIMESTAMP
            WHERE scheduled_date < CURRENT_TIMESTAMP
              AND status = 'scheduled'
            RETURNING id, interview_type, scheduled_date
        """)

        updated_interviews = cur.fetchall()
        conn.commit()

        logger.info(f"✅ Successfully updated {len(updated_interviews)} interviews to 'completed' status")

        # Step 4: Show final statistics
        cur.execute("""
            SELECT
                COUNT(*) as total_interviews,
                COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
                COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
                COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled
            FROM hirewire.interviews
        """)

        stats = cur.fetchone()
        total, scheduled, completed, cancelled = stats
        logger.info(f"Interview status summary: Total={total}, Scheduled={scheduled}, Completed={completed}, Cancelled={cancelled}")

        cur.close()
        conn.close()

    except Exception as e:
        logger.error(f"❌ Error updating past interviews: {e}")
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
