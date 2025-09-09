{% macro postgres_scan(table_name) %}
  postgres_scan('host=postgres port=5432 user=postgres password=password dbname=hirewire', 'hirewire', '{{ table_name }}')
{% endmacro %}