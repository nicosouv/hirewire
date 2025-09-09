{% macro postgres_scan(table_name) %}
  postgres_scan('host=postgres port=5432 user={{ env_var("POSTGRES_USER", "postgres") }} password={{ env_var("POSTGRES_PASSWORD", "password") }} dbname=hirewire', 'hirewire', '{{ table_name }}')
{% endmacro %}