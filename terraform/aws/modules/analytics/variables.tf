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

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
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

variable "dbt_image" {
  description = "Docker image for DBT (ECR URL)"
  type        = string
}

variable "dbt_command" {
  description = "Command to run in DBT container"
  type        = list(string)
  default     = ["dbt", "run", "--target", "duckdb"]
}

variable "task_cpu" {
  description = "CPU units for DBT task"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory for DBT task in MB"
  type        = number
  default     = 1024
}

variable "postgres_endpoint" {
  description = "PostgreSQL database endpoint"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL database port"
  type        = number
  default     = 5432
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL database user"
  type        = string
}

variable "postgres_password_secret_arn" {
  description = "ARN of the secret containing PostgreSQL password"
  type        = string
}

variable "enable_scheduled_runs" {
  description = "Enable EventBridge scheduled runs"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., 'cron(0 2 * * ? *)' for daily at 2 AM UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "create_separate_log_group" {
  description = "Create a separate CloudWatch log group for DBT"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 7
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "additional_environment_variables" {
  description = "Additional environment variables for DBT container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
