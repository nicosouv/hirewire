# ============================================
# HireWire AWS Infrastructure - Main Configuration
# ============================================
# Estimated Monthly Cost: $100-150 USD
# ============================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration (uncomment after first apply)
  # backend "s3" {
  #   bucket         = "hirewire-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "hirewire-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "HireWire"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
    }
  }
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# ============================================
# Local Variables
# ============================================

locals {
  project_name = "hirewire"
  common_tags = {
    Application = "HireWire"
    Environment = var.environment
  }

  # Cost estimation (monthly in USD)
  estimated_costs = {
    frontend      = 8   # S3 + CloudFront
    api           = 18  # ECS Fargate (0.5 vCPU, 1GB)
    database      = 50  # Aurora Serverless v2 (0.5-1 ACU)
    airflow       = 35  # ECS Fargate (1 vCPU, 2GB)
    dbt_analytics = 15  # ECS Fargate (0.5 vCPU, 1GB)
    storage       = 8   # S3 + EBS
    networking    = 12  # VPC Endpoints + Route53
    total         = 146
  }
}

# ============================================
# VPC and Networking
# ============================================

module "vpc" {
  source = "./modules/vpc"

  project_name = local.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets

  enable_nat_gateway   = false # Cost optimization: use VPC Endpoints instead
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# ============================================
# Security (KMS, Security Groups, IAM)
# ============================================

module "security" {
  source = "./modules/security"

  project_name = local.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr

  database_password = var.db_master_password

  create_redis_security_group = true

  tags = local.common_tags
}

# ============================================
# Aurora Serverless v2 Database
# ============================================

module "database" {
  source = "./modules/database"

  project_name = local.project_name
  environment  = var.environment

  vpc_id              = module.vpc.vpc_id
  database_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids  = [module.security.database_security_group_id]

  # Aurora Serverless v2 configuration
  engine_version  = "15.4"
  master_username = var.db_master_username
  master_password = var.db_master_password
  database_name   = "hirewire"

  # Auto-scaling configuration (cost optimization)
  serverlessv2_min_capacity = 0.5 # Minimum ACU (~$44/month)
  serverlessv2_max_capacity = 2   # Maximum ACU (~$175/month)

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  kms_key_id = module.security.kms_key_id

  tags = local.common_tags
}

# ============================================
# ECS Cluster
# ============================================

module "ecs" {
  source = "./modules/ecs"

  project_name = local.project_name
  environment  = var.environment

  enable_container_insights = true
  enable_fargate_spot       = var.enable_fargate_spot
  enable_ecs_exec           = true

  log_retention_days = 7
  kms_key_id         = module.security.kms_key_id

  secrets_arns = [
    module.security.database_password_secret_arn
  ]

  tags = local.common_tags
}

# ============================================
# Frontend (S3 + CloudFront)
# ============================================

module "frontend" {
  source = "./modules/frontend"

  project_name = local.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  # CloudFront configuration
  price_class = "PriceClass_100" # US, Canada, Europe only (cost optimization)

  tags = local.common_tags
}

# ============================================
# API Service (FastAPI Backend)
# ============================================

module "api" {
  source = "./modules/api"

  project_name = local.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  ecs_cluster_id   = module.ecs.cluster_id
  ecs_cluster_name = module.ecs.cluster_name

  task_execution_role_arn = module.ecs.task_execution_role_arn
  task_role_arn           = module.ecs.task_role_arn
  log_group_name          = module.ecs.log_group_name
  aws_region              = var.aws_region

  # Docker image (must be pushed to ECR first)
  api_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-api:latest"

  # ECS Task Configuration (cost optimized)
  task_cpu    = 512  # 0.5 vCPU (~$15/month)
  task_memory = 1024 # 1 GB

  # Auto-scaling
  desired_count = 1
  min_capacity  = 1
  max_capacity  = 3

  cpu_target_value    = 70
  memory_target_value = 80

  # Database connection
  database_endpoint            = module.database.cluster_endpoint
  database_port                = 5432
  database_name                = "hirewire"
  database_password_secret_arn = module.security.database_password_secret_arn

  # Health check
  health_check_path = "/health"

  enable_fargate_spot = var.enable_fargate_spot
  enable_ecs_exec     = true

  tags = local.common_tags
}

# ============================================
# Airflow Orchestration
# ============================================

# Note: Airflow requires Redis for Celery broker
# For production, add ElastiCache Redis module here

module "airflow" {
  source = "./modules/airflow"

  project_name = local.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  ecs_cluster_id = module.ecs.cluster_id

  task_execution_role_arn = module.ecs.task_execution_role_arn
  task_role_arn           = module.ecs.task_role_arn
  log_group_name          = module.ecs.log_group_name
  aws_region              = var.aws_region

  # Docker image (must be pushed to ECR first)
  airflow_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-airflow:latest"

  # ECS Task Configuration
  webserver_cpu    = 1024
  webserver_memory = 2048
  scheduler_cpu    = 1024
  scheduler_memory = 2048
  worker_cpu       = 1024
  worker_memory    = 2048
  worker_count     = 1

  # Database connection (Airflow metadata)
  database_endpoint = module.database.cluster_endpoint
  database_name     = "airflow"
  database_user     = var.db_master_username
  database_password = var.db_master_password

  # Redis URL (for Celery broker)
  # TODO: Replace with ElastiCache Redis endpoint
  redis_url = "redis://localhost:6379/0"

  # Airflow secrets (generate with: openssl rand -base64 32)
  fernet_key           = var.airflow_fernet_key
  webserver_secret_key = var.airflow_webserver_secret_key

  # Access control
  allowed_cidr_blocks = [var.vpc_cidr]

  enable_ecs_exec = true
  kms_key_id      = module.security.kms_key_id

  tags = local.common_tags
}

# ============================================
# DBT + DuckDB Analytics
# ============================================

module "analytics" {
  source = "./modules/analytics"

  project_name = local.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  ecs_cluster_arn = module.ecs.cluster_arn

  task_execution_role_arn = module.ecs.task_execution_role_arn
  task_role_arn           = module.ecs.task_role_arn
  log_group_name          = module.ecs.log_group_name
  aws_region              = var.aws_region

  # Docker image (must be pushed to ECR first)
  dbt_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-dbt:latest"

  # DBT command to run
  dbt_command = ["dbt", "run", "--target", "duckdb"]

  # ECS Task Configuration
  task_cpu    = 512
  task_memory = 1024

  # Database connection (source data from PostgreSQL)
  postgres_endpoint            = module.database.cluster_endpoint
  postgres_port                = 5432
  postgres_database            = "hirewire"
  postgres_user                = var.db_master_username
  postgres_password_secret_arn = module.security.database_password_secret_arn

  # Scheduled runs
  enable_scheduled_runs = true
  schedule_expression   = "cron(0 2 * * ? *)" # Daily at 2 AM UTC

  log_retention_days = 7
  kms_key_id         = module.security.kms_key_id

  tags = local.common_tags
}

# ============================================
# Monitoring and Alerting
# ============================================

module "monitoring" {
  source = "./modules/monitoring"

  project_name = local.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Cost monitoring
  monthly_budget_limit = var.monthly_budget_limit
  alert_email          = var.owner_email
  budget_alert_email   = var.owner_email

  # CloudWatch dashboards and alarms
  ecs_cluster_name       = module.ecs.cluster_name
  rds_cluster_identifier = module.database.cluster_id
  alb_arn                = module.api.alb_arn
  alb_arn_suffix         = split("/", module.api.alb_arn)[1]
  log_group_name         = module.ecs.log_group_name

  # Alarm thresholds
  ecs_cpu_threshold               = 80
  ecs_memory_threshold            = 85
  rds_cpu_threshold               = 80
  rds_connections_threshold       = 100
  alb_response_time_threshold     = 1
  alb_5xx_threshold               = 10
  application_errors_threshold    = 50

  kms_key_id = module.security.kms_key_id

  tags = local.common_tags
}

# ============================================
# Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "database_endpoint" {
  description = "Aurora Serverless v2 cluster endpoint"
  value       = module.database.cluster_endpoint
  sensitive   = true
}

output "database_cluster_id" {
  description = "Aurora Serverless v2 cluster ID"
  value       = module.database.cluster_id
}

output "api_endpoint" {
  description = "API Application Load Balancer endpoint"
  value       = module.api.api_endpoint
}

output "frontend_cloudfront_url" {
  description = "CloudFront distribution URL for frontend"
  value       = module.frontend.cloudfront_url
}

output "frontend_cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = module.frontend.cloudfront_distribution_id
}

output "frontend_s3_bucket" {
  description = "S3 bucket for frontend static files"
  value       = module.frontend.s3_bucket_name
}

output "airflow_s3_bucket" {
  description = "S3 bucket for Airflow DAGs and logs"
  value       = module.airflow.s3_bucket_name
}

output "analytics_s3_bucket" {
  description = "S3 bucket for analytics data (DuckDB)"
  value       = module.analytics.s3_bucket_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD"
  value = {
    frontend      = "$${local.estimated_costs.frontend}"
    api           = "$${local.estimated_costs.api}"
    database      = "$${local.estimated_costs.database}"
    airflow       = "$${local.estimated_costs.airflow}"
    dbt_analytics = "$${local.estimated_costs.dbt_analytics}"
    storage       = "$${local.estimated_costs.storage}"
    networking    = "$${local.estimated_costs.networking}"
    total         = "$${local.estimated_costs.total}"
  }
}

output "next_steps" {
  description = "Next steps for deployment"
  value = <<-EOT
    ✅ Infrastructure deployed successfully!

    Next steps:
    1. Push Docker images to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    2. Build and push API image:
       docker build -t hirewire-api ./backend
       docker tag hirewire-api:latest ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-api:latest
       docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-api:latest

    3. Build and push Airflow image:
       docker build -f .infra/docker/airflow.Dockerfile -t hirewire-airflow .
       docker tag hirewire-airflow:latest ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-airflow:latest
       docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-airflow:latest

    4. Build and push DBT image:
       docker build -f .infra/docker/dbt.Dockerfile -t hirewire-dbt .
       docker tag hirewire-dbt:latest ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-dbt:latest
       docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/hirewire-dbt:latest

    5. Deploy frontend to S3:
       cd frontend && npm run build
       aws s3 sync dist/ s3://${module.frontend.s3_bucket_name}/ --delete

    6. Initialize database:
       See DEPLOYMENT_GUIDE.md for database migration steps

    7. Access your services:
       - Frontend: ${module.frontend.cloudfront_url}
       - API: ${module.api.api_endpoint}

    8. Monitor costs:
       Check CloudWatch dashboard: ${module.monitoring.dashboard_name}
  EOT
}
