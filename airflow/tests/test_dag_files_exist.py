"""
Test that DAG files exist without importing Airflow modules

This is a minimal test that validates DAG files are present in the repository
without triggering Airflow 3.x import issues with Cadwyn/FastAPI/structlog.

For full DAG testing, see test_dag_integrity.py, test_dag_validation.py, and
test_dag_tasks.py (currently skipped due to Airflow 3.x compatibility issues).
"""
import os
from pathlib import Path


def test_dag_directory_exists():
    """Test that the dags directory exists"""
    dags_dir = Path(__file__).parent.parent / 'dags'
    assert dags_dir.exists(), "dags directory should exist"
    assert dags_dir.is_dir(), "dags should be a directory"


def test_expected_dag_files_exist():
    """Test that expected DAG files are present"""
    dags_dir = Path(__file__).parent.parent / 'dags'

    expected_dags = [
        'daily_etl_pipeline.py',
        'hourly_status_sync.py',
        'update_process_status.py',
        'update_past_interviews.py',
        'detect_ghosted_processes.py',
        'generate_export_report.py',
    ]

    for dag_file in expected_dags:
        dag_path = dags_dir / dag_file
        assert dag_path.exists(), f"DAG file {dag_file} should exist"
        assert dag_path.is_file(), f"{dag_file} should be a file"
        assert dag_path.stat().st_size > 0, f"{dag_file} should not be empty"


def test_dag_files_are_python():
    """Test that DAG files have Python extension"""
    dags_dir = Path(__file__).parent.parent / 'dags'

    for dag_file in dags_dir.glob('*.py'):
        # Skip __init__.py
        if dag_file.name == '__init__.py':
            continue

        # Check file is readable
        with open(dag_file, 'r') as f:
            content = f.read()
            assert len(content) > 0, f"{dag_file.name} should have content"

            # Basic sanity checks for DAG file structure
            assert 'from airflow' in content or 'import airflow' in content, (
                f"{dag_file.name} should import airflow"
            )
            assert 'DAG' in content, (
                f"{dag_file.name} should contain DAG definition"
            )
