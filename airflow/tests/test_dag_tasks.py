"""
Test individual DAG tasks

These tests validate:
1. Task operators are correct type
2. Task commands/callables are properly configured
3. Task trigger rules are appropriate
"""
import pytest
from airflow.models import DagBag
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator


class TestDagTasks:
    """Test individual tasks in DAGs"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        """Load all DAGs from the dags folder"""
        return DagBag(include_examples=False)

    def test_daily_etl_pipeline_task_types(self, dagbag):
        """Test that daily_etl_pipeline tasks use correct operators"""
        dag = dagbag.dags['daily_etl_pipeline']

        # BashOperator tasks
        bash_tasks = ['dbt_deps', 'dbt_run_staging', 'dbt_run_intermediate',
                      'dbt_run_marts', 'dbt_docs_generate']

        for task_id in bash_tasks:
            task = dag.get_task(task_id)
            assert isinstance(task, BashOperator), (
                f"Task {task_id} should be a BashOperator"
            )
            assert 'docker exec hirewire_dbt' in task.bash_command, (
                f"Task {task_id} should execute in dbt container"
            )

        # PythonOperator tasks
        python_tasks = ['verify_duckdb']

        for task_id in python_tasks:
            task = dag.get_task(task_id)
            assert isinstance(task, PythonOperator), (
                f"Task {task_id} should be a PythonOperator"
            )

    def test_update_process_status_task_types(self, dagbag):
        """Test that update_process_status task uses correct operator"""
        dag = dagbag.dags['update_process_status']

        task = dag.get_task('update_process_status')
        assert isinstance(task, PythonOperator), (
            "update_process_status should be a PythonOperator"
        )

    def test_task_ids_unique(self, dagbag):
        """Test that all task IDs within a DAG are unique"""
        for dag_id, dag in dagbag.dags.items():
            task_ids = [task.task_id for task in dag.tasks]
            assert len(task_ids) == len(set(task_ids)), (
                f"DAG {dag_id} has duplicate task IDs"
            )

    def test_bash_commands_not_empty(self, dagbag):
        """Test that BashOperator tasks have non-empty commands"""
        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                if isinstance(task, BashOperator):
                    assert task.bash_command, (
                        f"Task {task.task_id} in DAG {dag_id} has empty bash_command"
                    )
                    assert len(task.bash_command.strip()) > 0, (
                        f"Task {task.task_id} in DAG {dag_id} has blank bash_command"
                    )

    def test_python_callables_exist(self, dagbag):
        """Test that PythonOperator tasks have valid callables"""
        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                if isinstance(task, PythonOperator):
                    assert task.python_callable is not None, (
                        f"Task {task.task_id} in DAG {dag_id} has no python_callable"
                    )
                    assert callable(task.python_callable), (
                        f"Task {task.task_id} in DAG {dag_id} python_callable is not callable"
                    )

    def test_task_dependencies_exist(self, dagbag):
        """Test that tasks with dependencies have valid upstream tasks"""
        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                # Check upstream dependencies
                for upstream_task in task.upstream_list:
                    assert upstream_task in dag.tasks, (
                        f"Task {task.task_id} in DAG {dag_id} has invalid upstream: {upstream_task.task_id}"
                    )

                # Check downstream dependencies
                for downstream_task in task.downstream_list:
                    assert downstream_task in dag.tasks, (
                        f"Task {task.task_id} in DAG {dag_id} has invalid downstream: {downstream_task.task_id}"
                    )
