"""
Daily ETL Pipeline DAG

This DAG orchestrates the complete ETL pipeline:
1. Run DBT models (staging → intermediate → marts) in dedicated DBT container
2. Test data quality
3. Refresh DuckDB analytics database

Runs daily at 2 AM Paris time
"""

from datetime import datetime, timedelta
from airflow.models.dag import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.providers.standard.operators.python import PythonOperator
from docker.types import Mount
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
    'execution_timeout': timedelta(minutes=30),
}

# Define the DAG
with DAG(
    dag_id='daily_etl_pipeline',
    default_args=default_args,
    description='Daily ETL pipeline: DBT transformations in dedicated DBT container',
    schedule='0 2 * * *',  # Run at 2 AM Paris time
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['etl', 'dbt', 'daily'],
    max_active_runs=1,
) as dag:

    # Task 1: Install DBT dependencies
    dbt_deps = DockerOperator(
        task_id='dbt_deps',
        image='hirewire-dbt:latest',
        container_name='dbt_deps_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt deps',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        dag=dag,
    )

    # Task 2: Run DBT staging models
    dbt_run_staging = DockerOperator(
        task_id='dbt_run_staging',
        image='hirewire-dbt:latest',
        container_name='dbt_stg_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt run --models staging --target duckdb',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        dag=dag,
    )

    # Task 3: Run DBT intermediate models
    dbt_run_intermediate = DockerOperator(
        task_id='dbt_run_intermediate',
        image='hirewire-dbt:latest',
        container_name='dbt_int_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt run --models intermediate --target duckdb',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        dag=dag,
    )

    # Task 4: Run DBT marts models
    dbt_run_marts = DockerOperator(
        task_id='dbt_run_marts',
        image='hirewire-dbt:latest',
        container_name='dbt_marts_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt run --models marts --target duckdb',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        dag=dag,
    )

    # Task 5: Run DBT tests
    dbt_test = DockerOperator(
        task_id='dbt_test',
        image='hirewire-dbt:latest',
        container_name='dbt_test_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt test --target duckdb',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        trigger_rule='all_done',  # Run even if previous tasks fail
        dag=dag,
    )

    # Task 6: Generate DBT documentation
    dbt_docs = DockerOperator(
        task_id='dbt_docs_generate',
        image='hirewire-dbt:latest',
        container_name='dbt_docs_{{ ts_nodash }}',
        api_version='auto',
        auto_remove='success',
        command='dbt docs generate --target duckdb',
        docker_url='unix://var/run/docker.sock',
        network_mode='hirewire_network',
        mounts=[
            Mount(source='hirewire_duckdb_data', target='/data', type='volume'),
        ],
        mount_tmp_dir=False,
        environment={
            'POSTGRES_USER': '{{ var.value.get("POSTGRES_USER", "postgres") }}',
            'POSTGRES_PASSWORD': '{{ var.value.get("POSTGRES_PASSWORD", "password") }}',
        },
        trigger_rule='all_success',
        dag=dag,
    )

    # Task 7: Verify DuckDB database
    def verify_duckdb():
        """Verify DuckDB database has data"""
        import duckdb

        conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)

        # Check if marts exist
        tables = conn.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'main'
            AND table_name LIKE 'mart_%'
        """).fetchall()

        logger.info(f"Found {len(tables)} mart tables in DuckDB")

        if len(tables) == 0:
            raise ValueError("No mart tables found in DuckDB!")

        # Check row counts
        for table in tables:
            table_name = table[0]
            count = conn.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
            logger.info(f"Table {table_name}: {count} rows")

        conn.close()
        logger.info("DuckDB verification completed successfully")

    verify_duckdb_task = PythonOperator(
        task_id='verify_duckdb',
        python_callable=verify_duckdb,
        dag=dag,
    )

    # Define task dependencies
    dbt_deps >> dbt_run_staging >> dbt_run_intermediate >> dbt_run_marts >> [dbt_test, dbt_docs, verify_duckdb_task]
