# ============================================
# Aurora Serverless v2 Database Module
# ============================================
# Estimated Cost: $44-175/month (0.5-2 ACU auto-scaling)
# ============================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-${var.environment}"
  subnet_ids = var.database_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-db-subnet-${var.environment}"
    }
  )
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-cluster-${var.environment}"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  # Serverless v2 auto-scaling
  serverlessv2_scaling_configuration {
    min_capacity = var.serverlessv2_min_capacity
    max_capacity = var.serverlessv2_max_capacity
  }

  # Backup configuration
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-cluster-${var.environment}"
      CostCenter  = "Database"
      Serverless  = "v2"
    }
  )
}

resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.project_name}-instance-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id

  instance_class = "db.serverless"
  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version

  # Performance Insights (adds ~$7/month but useful)
  performance_insights_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-instance-${var.environment}"
    }
  )
}

# KMS Key for encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for ${var.project_name} RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rds-kms-${var.environment}"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

# ============================================
# Outputs
# ============================================

output "cluster_id" {
  description = "RDS Cluster ID"
  value       = aws_rds_cluster.main.id
}

output "cluster_endpoint" {
  description = "RDS Cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "RDS Cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "database_name" {
  description = "Database name"
  value       = aws_rds_cluster.main.database_name
}

output "port" {
  description = "Database port"
  value       = aws_rds_cluster.main.port
}
