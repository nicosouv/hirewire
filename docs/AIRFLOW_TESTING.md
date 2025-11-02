# Airflow DAG Testing Guide

This guide explains how to test Airflow DAGs for the HireWire project.

## Table of Contents

- [Why Test Airflow DAGs?](#why-test-airflow-dags)
- [Test Levels](#test-levels)
- [Running Tests](#running-tests)
- [Test Structure](#test-structure)
- [Writing New Tests](#writing-new-tests)
- [Best Practices](#best-practices)
- [CI/CD Integration](#cicd-integration)

## Why Test Airflow DAGs?

Testing DAGs is critical because:

1. **Prevent Runtime Errors**: Catch syntax errors, import issues, and configuration problems before deployment
2. **Validate Structure**: Ensure DAG dependencies, schedules, and task configurations are correct
3. **Maintain Quality**: Detect regressions when modifying existing DAGs
4. **Documentation**: Tests serve as living documentation of expected DAG behavior
5. **Faster Development**: Catch issues locally without needing to deploy to Airflow

## Test Levels

### 1. **DAG Integrity Tests** (`test_dag_integrity.py`)

Tests that ensure DAGs can be loaded and have basic structural correctness:

- ✅ **No Import Errors**: All DAG files can be imported without Python errors
- ✅ **DAG Count**: Expected number of DAGs are present
- ✅ **No Cycles**: DAG task dependencies don't have cycles
- ✅ **Required Properties**: DAGs have owners, tags, retries configured
- ✅ **Catchup Disabled**: Prevents backfilling old DAG runs

**Example:**
```python
def test_no_import_errors(self, dagbag):
    """Test that all DAG files can be imported without errors"""
    assert not dagbag.import_errors, (
        f"DAG import failures. Errors: {dagbag.import_errors}"
    )
```

### 2. **DAG Validation Tests** (`test_dag_validation.py`)

Tests that validate specific DAG configurations:

- ✅ **Schedule Intervals**: Correct cron expressions for each DAG
- ✅ **Task Count**: Expected number of tasks per DAG
- ✅ **Retry Configuration**: Proper retry settings for reliability
- ✅ **Timeout Configuration**: Execution timeouts prevent hanging tasks
- ✅ **Task Dependencies**: Correct task execution order

**Example:**
```python
def test_daily_etl_pipeline_structure(self, dagbag):
    """Test daily_etl_pipeline DAG structure"""
    dag = dagbag.dags['daily_etl_pipeline']

    # Check schedule
    assert dag.schedule_interval == '0 2 * * *'

    # Check task dependencies
    dbt_deps = dag.get_task('dbt_deps')
    dbt_run_staging = dag.get_task('dbt_run_staging')
    assert dbt_run_staging in dbt_deps.downstream_list
```

### 3. **Task Tests** (`test_dag_tasks.py`)

Tests that validate individual task configurations:

- ✅ **Operator Types**: Tasks use correct operators (BashOperator, PythonOperator, etc.)
- ✅ **Task Commands**: Bash commands are non-empty and valid
- ✅ **Python Callables**: Python functions exist and are callable
- ✅ **Unique Task IDs**: No duplicate task IDs within a DAG

**Example:**
```python
def test_bash_commands_not_empty(self, dagbag):
    """Test that BashOperator tasks have non-empty commands"""
    for dag_id, dag in dagbag.dags.items():
        for task in dag.tasks:
            if isinstance(task, BashOperator):
                assert task.bash_command
```

## Running Tests

### Local Testing (Recommended)

Run tests locally before committing changes:

```bash
# Navigate to airflow directory
cd airflow

# Install test dependencies (first time only)
pip install -r requirements-test.txt

# Run all tests
pytest

# Run with verbose output
pytest -v

# Run specific test file
pytest tests/test_dag_integrity.py

# Run specific test class
pytest tests/test_dag_integrity.py::TestDagIntegrity

# Run specific test
pytest tests/test_dag_integrity.py::TestDagIntegrity::test_no_import_errors

# Run with coverage report
pytest --cov=dags --cov-report=html

# Run only fast unit tests
pytest -m unit

# Skip slow tests
pytest -m "not slow"
```

### Docker Testing

Run tests inside Airflow container:

```bash
# Execute tests in airflow-webserver container
docker-compose exec airflow-webserver bash -c "cd /opt/airflow && pytest tests/"

# Or copy test files and run
docker cp airflow/tests airflow-webserver:/opt/airflow/
docker cp airflow/pytest.ini airflow-webserver:/opt/airflow/
docker-compose exec airflow-webserver pytest /opt/airflow/tests/
```

### Continuous Integration

Tests should run automatically on every commit/PR:

```yaml
# .github/workflows/test-dags.yml
name: Test Airflow DAGs

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          cd airflow
          pip install -r requirements-test.txt
      - name: Run DAG tests
        run: |
          cd airflow
          pytest -v --cov=dags --cov-report=xml
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

## Test Structure

```
airflow/
├── dags/                          # DAG definitions
│   ├── daily_etl_pipeline.py
│   ├── update_process_status.py
│   └── ...
├── tests/                         # Test suite
│   ├── __init__.py
│   ├── conftest.py               # Pytest configuration & fixtures
│   ├── test_dag_integrity.py     # Structural integrity tests
│   ├── test_dag_validation.py    # Configuration validation tests
│   └── test_dag_tasks.py         # Individual task tests
├── pytest.ini                     # Pytest settings
└── requirements-test.txt          # Test dependencies
```

## Writing New Tests

### Adding a New DAG Test

When creating a new DAG, add corresponding tests:

```python
# tests/test_dag_validation.py

def test_my_new_dag_structure(self, dagbag):
    """Test my_new_dag DAG structure"""
    dag_id = 'my_new_dag'
    assert dag_id in dagbag.dags, f"DAG {dag_id} not found"

    dag = dagbag.dags[dag_id]

    # Check schedule
    assert dag.schedule_interval == '0 */4 * * *'

    # Check expected tasks
    expected_tasks = {'task1', 'task2', 'task3'}
    actual_tasks = {task.task_id for task in dag.tasks}
    assert expected_tasks == actual_tasks

    # Check task dependencies
    task1 = dag.get_task('task1')
    task2 = dag.get_task('task2')
    assert task2 in task1.downstream_list
```

### Testing Python Callables

For DAGs with PythonOperator tasks:

```python
# tests/test_my_dag_functions.py

from dags.my_dag import my_python_function

def test_my_python_function():
    """Test the Python callable directly"""
    result = my_python_function()
    assert result is not None
    assert isinstance(result, dict)
```

### Mocking External Dependencies

For tasks that call external APIs:

```python
# tests/test_api_calls.py

from unittest.mock import patch, MagicMock

def test_api_task_success(self, dagbag):
    """Test API call task with mocked response"""
    with patch('requests.post') as mock_post:
        # Mock successful API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {'status': 'success'}
        mock_post.return_value = mock_response

        # Get and test the task callable
        dag = dagbag.dags['my_api_dag']
        task = dag.get_task('call_api')

        # Execute the task's callable
        result = task.python_callable()

        # Verify it was called correctly
        mock_post.assert_called_once()
        assert result == {'status': 'success'}
```

## Best Practices

### 1. **Test DAG Loading First**

Always ensure DAGs can be loaded before testing specific functionality:

```python
def test_dag_loads(self, dagbag):
    """Test that DAG loads without errors"""
    assert 'my_dag' in dagbag.dags
    assert not dagbag.import_errors
```

### 2. **Use Fixtures for Common Setup**

Define reusable fixtures in `conftest.py`:

```python
# conftest.py

@pytest.fixture(scope="class")
def dagbag():
    """Load all DAGs once per test class"""
    return DagBag(include_examples=False)

@pytest.fixture
def daily_etl_dag(dagbag):
    """Return the daily ETL DAG"""
    return dagbag.dags['daily_etl_pipeline']
```

### 3. **Test Task Dependencies Explicitly**

Verify the task execution order is correct:

```python
def test_task_order(self, dagbag):
    """Test that tasks execute in correct order"""
    dag = dagbag.dags['my_dag']

    # Task A should run before Task B
    task_a = dag.get_task('task_a')
    task_b = dag.get_task('task_b')

    assert task_b in task_a.downstream_list
    assert task_a in task_b.upstream_list
```

### 4. **Validate Schedules for Business Requirements**

Ensure schedules match business needs:

```python
def test_business_hours_schedule(self, dagbag):
    """Test that status sync runs during business hours"""
    dag = dagbag.dags['hourly_status_sync']

    # Should run 9 AM - 7 PM, Monday-Friday
    assert dag.schedule_interval == '0 9-19 * * 1-5'
```

### 5. **Test Error Handling**

Verify retry and timeout configurations:

```python
def test_retry_configuration(self, dagbag):
    """Test that critical DAGs have retries configured"""
    critical_dags = ['daily_etl_pipeline']

    for dag_id in critical_dags:
        dag = dagbag.dags[dag_id]
        assert dag.default_args['retries'] >= 2
        assert dag.default_args['retry_delay'].total_seconds() >= 300
```

### 6. **Keep Tests Fast**

- Use mocks for external dependencies (databases, APIs)
- Mark slow tests with `@pytest.mark.slow`
- Run fast unit tests frequently during development

### 7. **Test DAG Updates Don't Break Existing Functionality**

When modifying a DAG, ensure tests validate backward compatibility:

```python
def test_dag_backward_compatibility(self, dagbag):
    """Test that DAG changes maintain existing functionality"""
    dag = dagbag.dags['my_dag']

    # Critical tasks should still exist
    required_tasks = ['critical_task_1', 'critical_task_2']
    actual_tasks = {task.task_id for task in dag.tasks}

    for task_id in required_tasks:
        assert task_id in actual_tasks, f"Critical task {task_id} removed!"
```

## Test Coverage

### Current Coverage

Our test suite covers:

- ✅ **100% DAG Import Success**: All DAG files parse without errors
- ✅ **DAG Structure**: Task counts, dependencies, cycles
- ✅ **Scheduling**: Correct cron expressions for all DAGs
- ✅ **Retry Logic**: Proper error handling configuration
- ✅ **Task Types**: Correct operators used for each task

### Coverage Gaps (Future Improvements)

- ⚠️ **Integration Tests**: End-to-end DAG execution (requires running Airflow)
- ⚠️ **Data Quality Tests**: Verify output data meets expectations
- ⚠️ **Performance Tests**: Ensure DAGs complete within SLA
- ⚠️ **API Endpoint Tests**: Test Backend API calls in DAGs

## CI/CD Integration

### Pre-commit Hook

Add DAG tests to pre-commit hooks:

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running Airflow DAG tests..."
cd airflow
pytest tests/ -q

if [ $? -ne 0 ]; then
    echo "❌ DAG tests failed! Commit aborted."
    exit 1
fi

echo "✅ DAG tests passed!"
```

### GitHub Actions Workflow

See `.github/workflows/test-dags.yml` for automated testing on every push.

### Pre-deployment Validation

Before deploying to production:

```bash
# Run full test suite with coverage
cd airflow
pytest --cov=dags --cov-report=term-missing

# Ensure coverage is above threshold (e.g., 80%)
pytest --cov=dags --cov-fail-under=80
```

## Troubleshooting

### Common Issues

**1. Import Errors**

```
ImportError: No module named 'airflow'
```

**Solution**: Install test dependencies
```bash
pip install -r requirements-test.txt
```

**2. DagBag Returns Empty**

```
AssertionError: No DAGs found in DagBag
```

**Solution**: Check `AIRFLOW__CORE__DAGS_FOLDER` environment variable
```python
# conftest.py
os.environ["AIRFLOW__CORE__DAGS_FOLDER"] = str(DAGS_DIR)
```

**3. Tests Pass Locally But Fail in CI**

**Solution**: Ensure CI has same Python version and dependencies
```yaml
# .github/workflows/test-dags.yml
- uses: actions/setup-python@v4
  with:
    python-version: '3.11'  # Match local environment
```

## Summary

Testing Airflow DAGs provides:

- ✅ **Confidence**: Deploy DAGs knowing they're structurally sound
- ✅ **Fast Feedback**: Catch errors in seconds, not hours
- ✅ **Documentation**: Tests describe expected DAG behavior
- ✅ **Maintainability**: Refactor safely with regression tests
- ✅ **Quality**: Enforce best practices automatically

**Next Steps:**
1. Run tests locally: `cd airflow && pytest -v`
2. Add tests when creating new DAGs
3. Set up CI/CD to run tests automatically
4. Aim for >80% test coverage

For questions or improvements, see the [Airflow Testing documentation](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html#testing-dags).
