"""
Generate Export Report DAG

This DAG handles user export requests:
1. Fetch data from the backend API
2. Generate Excel or CSV file
3. Send email with the export file attached
4. Update export status in database

Triggered on-demand via API call from the backend.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
import logging
import pandas as pd
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import httpx

logger = logging.getLogger(__name__)

# Configuration
EXPORTS_DIR = "/tmp/exports"
BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://api:8000")

# Email configuration
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM = os.getenv("SMTP_FROM", SMTP_USER)


def extract_export_data(**context):
    """
    Fetch export data from the backend API.
    """
    conf = context['dag_run'].conf
    export_id = conf['export_id']

    logger.info(f"Fetching data for export {export_id} from backend API")

    # Call backend API to get export data
    try:
        response = httpx.get(
            f"{BACKEND_API_URL}/api/v1/exports/{export_id}/data",
            timeout=30.0
        )
        response.raise_for_status()
        data = response.json()

        logger.info(f"Successfully fetched data: {len(data.get('applications', []))} applications, {len(data.get('interviews', []))} interviews")

        # Store data in XCom for next task
        ti = context['task_instance']
        ti.xcom_push(key='export_data', value=data)

        return data

    except Exception as e:
        logger.error(f"Failed to fetch export data: {str(e)}")
        raise


def generate_export_file(**context):
    """
    Generate Excel or CSV file from export data.
    """
    ti = context['task_instance']
    data = ti.xcom_pull(key='export_data', task_ids='extract_data')

    export_info = data['export']
    export_id = export_info['id']
    export_format = export_info['format']

    # Create exports directory
    os.makedirs(EXPORTS_DIR, exist_ok=True)

    # Convert data to DataFrames
    df_applications = pd.DataFrame(data['applications'])
    df_interviews = pd.DataFrame(data['interviews'])
    df_stats = pd.DataFrame([data['statistics']])
    df_company_stats = pd.DataFrame(data['company_statistics'])

    logger.info(f"Generating {export_format} file for export {export_id}")

    # Generate filename
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    if export_format == 'excel':
        filename = f"export_{export_id}_{timestamp}.xlsx"
        filepath = os.path.join(EXPORTS_DIR, filename)

        # Create Excel file with multiple sheets
        with pd.ExcelWriter(filepath, engine='xlsxwriter') as writer:
            df_stats.to_excel(writer, sheet_name='Summary', index=False)
            df_applications.to_excel(writer, sheet_name='Applications', index=False)
            df_interviews.to_excel(writer, sheet_name='Interviews', index=False)
            df_company_stats.to_excel(writer, sheet_name='Companies', index=False)

        logger.info(f"Excel file created: {filepath}")

    else:  # CSV format
        filename = f"export_{export_id}_{timestamp}.csv"
        filepath = os.path.join(EXPORTS_DIR, filename)

        # Combine all data into one CSV with headers
        with open(filepath, 'w') as f:
            f.write("=== SUMMARY ===\n")
            df_stats.to_csv(f, index=False)
            f.write("\n=== APPLICATIONS ===\n")
            df_applications.to_csv(f, index=False)
            f.write("\n=== INTERVIEWS ===\n")
            df_interviews.to_csv(f, index=False)
            f.write("\n=== COMPANIES ===\n")
            df_company_stats.to_csv(f, index=False)

        logger.info(f"CSV file created: {filepath}")

    # Store filepath in XCom
    ti.xcom_push(key='export_filepath', value=filepath)

    return filepath


def send_email_with_attachment(**context):
    """
    Send email with export file attached.
    """
    ti = context['task_instance']
    data = ti.xcom_pull(key='export_data', task_ids='extract_data')
    filepath = ti.xcom_pull(key='export_filepath', task_ids='generate_file')

    export_info = data['export']
    recipient_email = export_info['recipient_email']
    start_date = export_info['start_date']
    end_date = export_info['end_date']

    logger.info(f"Sending export to {recipient_email}")

    # Create email
    msg = MIMEMultipart()
    msg['From'] = SMTP_FROM
    msg['To'] = recipient_email
    msg['Subject'] = f"HireWire Export Report - {start_date} to {end_date}"

    # Email body
    body = f"""
    Hello,

    Your HireWire export report is ready!

    Period: {start_date} to {end_date}
    Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

    Please find the export file attached to this email.

    Best regards,
    HireWire Team
    """

    msg.attach(MIMEText(body, 'plain'))

    # Attach file
    with open(filepath, 'rb') as attachment:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(attachment.read())
        encoders.encode_base64(part)
        part.add_header(
            'Content-Disposition',
            f'attachment; filename={os.path.basename(filepath)}'
        )
        msg.attach(part)

    # Send email
    try:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)
        server.quit()

        logger.info(f"Email sent successfully to {recipient_email}")
    except Exception as e:
        logger.error(f"Failed to send email: {str(e)}")
        raise


def update_export_status(**context):
    """
    Update export status in the database.
    """
    conf = context['dag_run'].conf
    export_id = conf['export_id']

    # Get filepath from XCom
    ti = context['task_instance']
    filepath = ti.xcom_pull(key='export_filepath', task_ids='generate_file')

    # Determine status based on task execution
    task_instance = context['task_instance']
    if task_instance.state == 'success':
        status = 'completed'
        error_message = None
    else:
        status = 'failed'
        error_message = "Export generation or email sending failed"

    # Update via backend API
    try:
        response = httpx.patch(
            f"{BACKEND_API_URL}/api/v1/exports/{export_id}",
            json={
                "status": status,
                "file_path": filepath,
                "error_message": error_message,
                "completed_at": datetime.now().isoformat()
            },
            timeout=10.0
        )

        if response.status_code == 200:
            logger.info(f"Export {export_id} status updated to {status}")
        else:
            logger.error(f"Failed to update export status: {response.text}")
    except Exception as e:
        logger.error(f"Error updating export status: {str(e)}")


# Default arguments
default_args = {
    'owner': 'hirewire',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
    'execution_timeout': timedelta(minutes=15),
}

# Define the DAG
with DAG(
    dag_id='generate_export_report',
    default_args=default_args,
    description='Generate export report and send via email',
    schedule=None,  # Triggered manually
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['export', 'report', 'email'],
    max_active_runs=5,  # Allow multiple concurrent exports
) as dag:

    # Task 1: Extract data from backend API
    extract_data = PythonOperator(
        task_id='extract_data',
        python_callable=extract_export_data
    )

    # Task 2: Generate export file
    generate_file = PythonOperator(
        task_id='generate_file',
        python_callable=generate_export_file
    )

    # Task 3: Send email
    send_email = PythonOperator(
        task_id='send_email',
        python_callable=send_email_with_attachment
    )

    # Task 4: Update export status
    update_status = PythonOperator(
        task_id='update_status',
        python_callable=update_export_status,
        trigger_rule='all_done'  # Run even if previous tasks failed
    )

    # Define task dependencies
    extract_data >> generate_file >> send_email >> update_status
