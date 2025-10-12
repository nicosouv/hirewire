variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS tasks"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "airflow_image" {
  description = "Docker image for Airflow (ECR URL)"
  type        = string
}

variable "database_endpoint" {
  description = "Database endpoint for Airflow metadata"
  type        = string
}

variable "database_name" {
  description = "Database name for Airflow metadata"
  type        = string
  default     = "airflow"
}

variable "database_user" {
  description = "Database user for Airflow"
  type        = string
  default     = "airflow"
}

variable "database_password" {
  description = "Database password for Airflow"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis URL for Celery broker (e.g., redis://host:6379/0)"
  type        = string
}

variable "fernet_key" {
  description = "Airflow Fernet key for encrypting sensitive data"
  type        = string
  sensitive   = true
}

variable "webserver_secret_key" {
  description = "Airflow webserver secret key"
  type        = string
  sensitive   = true
}

variable "webserver_cpu" {
  description = "CPU units for webserver task"
  type        = number
  default     = 1024
}

variable "webserver_memory" {
  description = "Memory for webserver task in MB"
  type        = number
  default     = 2048
}

variable "scheduler_cpu" {
  description = "CPU units for scheduler task"
  type        = number
  default     = 1024
}

variable "scheduler_memory" {
  description = "Memory for scheduler task in MB"
  type        = number
  default     = 2048
}

variable "worker_cpu" {
  description = "CPU units for worker task"
  type        = number
  default     = 1024
}

variable "worker_memory" {
  description = "Memory for worker task in MB"
  type        = number
  default     = 2048
}

variable "worker_count" {
  description = "Number of worker tasks"
  type        = number
  default     = 1
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Airflow webserver"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting S3 bucket"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
