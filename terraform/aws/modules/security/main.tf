# KMS Key for encrypting sensitive data
resource "aws_kms_key" "main" {
  description             = "${var.project_name} encryption key - ${var.environment}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-kms-${var.environment}"
    }
  )
}

# KMS Key Alias
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# Security Group for RDS Database
resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg-${var.environment}"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = concat(var.allowed_security_group_ids, [aws_security_group.ecs_tasks.id])
    description     = "Allow PostgreSQL from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-database-sg-${var.environment}"
    }
  )
}

# Security Group for ECS Tasks (generic)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg-${var.environment}"
  description = "Generic security group for ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-tasks-sg-${var.environment}"
    }
  )
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
    }
  )
}

# Security Group for Redis (ElastiCache)
resource "aws_security_group" "redis" {
  count       = var.create_redis_security_group ? 1 : 0
  name        = "${var.project_name}-redis-sg-${var.environment}"
  description = "Security group for Redis cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "Allow Redis from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-redis-sg-${var.environment}"
    }
  )
}

# IAM Policy Document for S3 access
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "AllowS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = concat(
      [for bucket_arn in var.s3_bucket_arns : "${bucket_arn}/*"],
      var.s3_bucket_arns
    )
  }
}

# IAM Policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-${var.environment}"
  description = "Policy for S3 bucket access"
  policy      = data.aws_iam_policy_document.s3_access.json

  tags = var.tags
}

# IAM Policy Document for Secrets Manager access
data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "AllowSecretsAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = var.secrets_arns
  }
}

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-access-${var.environment}"
  description = "Policy for Secrets Manager access"
  policy      = data.aws_iam_policy_document.secrets_access.json

  tags = var.tags
}

# IAM Policy Document for KMS access
data "aws_iam_policy_document" "kms_access" {
  statement {
    sid    = "AllowKMSAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.main.arn]
  }
}

# IAM Policy for KMS access
resource "aws_iam_policy" "kms_access" {
  name        = "${var.project_name}-kms-access-${var.environment}"
  description = "Policy for KMS key access"
  policy      = data.aws_iam_policy_document.kms_access.json

  tags = var.tags
}

# IAM Policy Document for CloudWatch Logs
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.project_name}-cloudwatch-logs-${var.environment}"
  description = "Policy for CloudWatch Logs access"
  policy      = data.aws_iam_policy_document.cloudwatch_logs.json

  tags = var.tags
}

# IAM Policy Document for ECR access
data "aws_iam_policy_document" "ecr_access" {
  statement {
    sid    = "AllowECRAccess"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}

# IAM Policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "${var.project_name}-ecr-access-${var.environment}"
  description = "Policy for ECR access"
  policy      = data.aws_iam_policy_document.ecr_access.json

  tags = var.tags
}

# Secrets Manager secret for database password
resource "aws_secretsmanager_secret" "database_password" {
  name        = "${var.project_name}/database/password-${var.environment}"
  description = "Database master password"
  kms_key_id  = aws_kms_key.main.id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = var.database_password
}
