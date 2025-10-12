variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = null
}

variable "budget_alert_email" {
  description = "Email address for budget alerts"
  type        = string
  default     = null
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 150
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for monitoring"
  type        = string
}

variable "rds_cluster_identifier" {
  description = "RDS cluster identifier for monitoring"
  type        = string
  default     = null
}

variable "alb_arn" {
  description = "ALB ARN for monitoring"
  type        = string
  default     = null
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (last part of ARN) for CloudWatch metrics"
  type        = string
  default     = null
}

variable "log_group_name" {
  description = "CloudWatch log group name for metric filters"
  type        = string
  default     = null
}

variable "ecs_cpu_threshold" {
  description = "ECS CPU threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "ECS memory threshold for alarms (%)"
  type        = number
  default     = 85
}

variable "rds_cpu_threshold" {
  description = "RDS CPU threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "rds_connections_threshold" {
  description = "RDS connections threshold for alarms"
  type        = number
  default     = 100
}

variable "alb_response_time_threshold" {
  description = "ALB response time threshold for alarms (seconds)"
  type        = number
  default     = 1
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx error count threshold for alarms"
  type        = number
  default     = 10
}

variable "application_errors_threshold" {
  description = "Application error count threshold for alarms"
  type        = number
  default     = 50
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting SNS topics"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
