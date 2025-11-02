# Airflow DAG Tests

Quick reference for testing Airflow DAGs in the HireWire project.

## Quick Start

```bash
# Install test dependencies
cd airflow
pip install -r requirements-test.txt

# Run all tests
pytest

# Run with verbose output
pytest -v

# Run with coverage
pytest --cov=dags --cov-report=html
```

## Test Files

| File | Purpose |
|------|---------|
| `test_dag_integrity.py` | DAG structure and imports |
| `test_dag_validation.py` | DAG configurations and schedules |
| `test_dag_tasks.py` | Individual task validation |

## What Gets Tested

✅ **Import Validation**: All DAG files import without errors
✅ **Structure**: Tasks, dependencies, no cycles
✅ **Schedules**: Correct cron expressions
✅ **Configuration**: Retries, timeouts, catchup disabled
✅ **Tasks**: Proper operators, commands, callables

## Current DAGs Tested

- `daily_etl_pipeline` - Daily at 2 AM
- `hourly_status_sync` - Hourly 9 AM - 7 PM (Mon-Fri)
- `update_process_status` - Hourly 9 AM - 7 PM (Mon-Fri)
- `update_past_interviews` - Every 6 hours
- `detect_ghosted_processes` - Daily at 4 AM
- `generate_export_report` - Manual trigger only

## Common Commands

```bash
# Run specific test file
pytest tests/test_dag_integrity.py

# Run specific test
pytest tests/test_dag_integrity.py::TestDagIntegrity::test_no_import_errors

# Watch mode (re-run on file changes)
pytest-watch

# Generate HTML coverage report
pytest --cov=dags --cov-report=html
open htmlcov/index.html
```

## Adding Tests for New DAGs

When creating a new DAG, add tests to `test_dag_validation.py`:

```python
def test_my_new_dag_structure(self, dagbag):
    """Test my_new_dag DAG structure"""
    dag = dagbag.dags['my_new_dag']

    # Check schedule
    assert dag.schedule_interval == '0 */4 * * *'

    # Check tasks exist
    expected_tasks = {'task1', 'task2'}
    actual_tasks = {task.task_id for task in dag.tasks}
    assert expected_tasks.issubset(actual_tasks)
```

## Documentation

For detailed testing guide, see: [docs/AIRFLOW_TESTING.md](../docs/AIRFLOW_TESTING.md)

## CI/CD

Tests run automatically on:
- Every commit (pre-commit hook)
- Every push (GitHub Actions)
- Before deployment (manual validation)

Minimum coverage threshold: **80%**
