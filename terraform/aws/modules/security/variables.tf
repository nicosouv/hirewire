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

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "allowed_security_group_ids" {
  description = "Additional security group IDs allowed to access database"
  type        = list(string)
  default     = []
}

variable "create_redis_security_group" {
  description = "Create security group for Redis"
  type        = bool
  default     = true
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "secrets_arns" {
  description = "List of Secrets Manager ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "database_password" {
  description = "Database master password to store in Secrets Manager"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
