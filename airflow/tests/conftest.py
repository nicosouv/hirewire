"""
Pytest configuration for Airflow DAG tests
"""
import os
import sys
from pathlib import Path

import pytest

# Add dags directory to Python path
DAGS_DIR = Path(__file__).parent.parent / "dags"
sys.path.insert(0, str(DAGS_DIR))

# Set Airflow home for tests
os.environ["AIRFLOW_HOME"] = str(Path(__file__).parent.parent)
os.environ["AIRFLOW__CORE__DAGS_FOLDER"] = str(DAGS_DIR)
os.environ["AIRFLOW__CORE__LOAD_EXAMPLES"] = "False"
os.environ["AIRFLOW__CORE__UNIT_TEST_MODE"] = "True"


@pytest.fixture
def dags_folder():
    """Return the path to the dags folder"""
    return DAGS_DIR
