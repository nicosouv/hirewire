# ============================================
# HireWire AWS Infrastructure - Variables
# ============================================

# ============================================
# General Configuration
# ============================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "owner_email" {
  description = "Email address for cost alerts and notifications"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

# ============================================
# VPC Configuration
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ============================================
# Database Configuration
# ============================================

variable "db_master_username" {
  description = "Master username for Aurora database"
  type        = string
  default     = "hirewire_admin"
  sensitive   = true
}

variable "db_master_password" {
  description = "Master password for Aurora database"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_master_password) >= 16
    error_message = "Database password must be at least 16 characters long."
  }
}

# ============================================
# Cost Management
# ============================================

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 150

  validation {
    condition     = var.monthly_budget_limit >= 50
    error_message = "Monthly budget must be at least $50 to run the infrastructure."
  }
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization features (Fargate Spot, S3 Intelligent-Tiering, etc.)"
  type        = bool
  default     = true
}

# ============================================
# Feature Flags
# ============================================

variable "enable_superset" {
  description = "Enable Apache Superset for data visualization"
  type        = bool
  default     = false # Disabled by default to save costs
}

variable "enable_monitoring" {
  description = "Enable CloudWatch Container Insights and enhanced monitoring"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automated backups for database"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for cost savings (70% discount, but may be interrupted)"
  type        = bool
  default     = false
}

# ============================================
# Airflow Configuration
# ============================================

variable "airflow_fernet_key" {
  description = "Airflow Fernet key for encrypting sensitive data (generate with: openssl rand -base64 32)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "airflow_webserver_secret_key" {
  description = "Airflow webserver secret key (generate with: openssl rand -base64 32)"
  type        = string
  sensitive   = true
  default     = ""
}
