# Superset configuration for HireWire
import os

# Database configuration
SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'postgresql://superset:superset@postgres:5432/superset')

# Redis configuration
REDIS_HOST = os.environ.get('REDIS_HOST', 'redis')
REDIS_PORT = os.environ.get('REDIS_PORT', 6379)

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': REDIS_HOST,
    'CACHE_REDIS_PORT': REDIS_PORT,
    'CACHE_REDIS_DB': 1,
}

# Celery configuration
class CeleryConfig:
    broker_url = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    imports = ('superset.sql_lab',)
    result_backend = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    worker_prefetch_multiplier = 1
    task_acks_late = False

CELERY_CONFIG = CeleryConfig

# Feature flags
FEATURE_FLAGS = {
    'DASHBOARD_NATIVE_FILTERS': True,
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_RBAC': True,
    'EMBEDDABLE_CHARTS': True,
    'ESTIMATED_QUERY_COST': False,
    'ENABLE_ADVANCED_DATA_TYPES': True,
}

# Security
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'change-this-secret-key-for-production')

# DuckDB specific configuration
PREFERRED_DATABASES = [
    {
        'name': 'HireWire Analytics',
        'description': 'DuckDB database for HireWire interview analytics',
        'available_drivers': ['duckdb'],
        'engine': 'duckdb',
        'default_driver': 'duckdb',
        'sqlalchemy_uri_placeholder': 'duckdb:////app/duckdb-data/hirewire.duckdb',
    }
]

# Custom CSS
CUSTOM_CSS = '''
.navbar-brand {
    font-weight: bold;
}
.navbar-brand:after {
    content: " - HireWire Analytics";
    font-weight: normal;
    opacity: 0.7;
}
'''

# Dashboard configuration
DASHBOARD_AUTO_REFRESH_MODE = "fetch"
DASHBOARD_AUTO_REFRESH_INTERVALS = [
    [0, "Don't refresh"],
    [10, "10 seconds"],
    [30, "30 seconds"],
    [60, "1 minute"],
    [300, "5 minutes"],
    [1800, "30 minutes"],
    [3600, "1 hour"],
]

# SQL Lab configuration
SQLLAB_CTAS_NO_LIMIT = True
SQL_MAX_ROW = 100000

# File upload configuration
UPLOAD_FOLDER = '/app/superset_home/uploads/'
UPLOAD_CHUNK_SIZE = 4096

# Email configuration (optional)
SMTP_HOST = os.environ.get('SMTP_HOST')
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = os.environ.get('SMTP_USER')
SMTP_PASSWORD = os.environ.get('SMTP_PASSWORD')
SMTP_MAIL_FROM = os.environ.get('SMTP_MAIL_FROM')

# Logging
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = 'INFO'
FILENAME = os.path.join('/app/superset_home', 'superset.log')