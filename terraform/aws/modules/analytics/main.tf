# S3 Bucket for DuckDB analytics data
resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project_name}-analytics-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-${var.environment}"
    }
  )
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Intelligent-Tiering for cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id
  name   = "EntireBucket"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Security Group for DBT tasks
resource "aws_security_group" "dbt" {
  name        = "${var.project_name}-dbt-sg-${var.environment}"
  description = "Security group for DBT ECS tasks"
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
      Name = "${var.project_name}-dbt-sg-${var.environment}"
    }
  )
}

# ECS Task Definition for DBT
resource "aws_ecs_task_definition" "dbt" {
  family                   = "${var.project_name}-dbt-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "dbt"
      image     = var.dbt_image
      essential = true
      command   = var.dbt_command

      environment = concat(
        [
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "POSTGRES_HOST"
            value = var.postgres_endpoint
          },
          {
            name  = "POSTGRES_PORT"
            value = tostring(var.postgres_port)
          },
          {
            name  = "POSTGRES_DATABASE"
            value = var.postgres_database
          },
          {
            name  = "POSTGRES_USER"
            value = var.postgres_user
          },
          {
            name  = "DUCKDB_PATH"
            value = "/data/hirewire.duckdb"
          },
          {
            name  = "S3_BUCKET"
            value = aws_s3_bucket.analytics.id
          }
        ],
        var.additional_environment_variables
      )

      secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = var.postgres_password_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "dbt"
        }
      }

      mountPoints = []
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-dbt-${var.environment}"
    }
  )
}

# EventBridge rule for scheduled DBT runs
resource "aws_cloudwatch_event_rule" "dbt_daily" {
  count               = var.enable_scheduled_runs ? 1 : 0
  name                = "${var.project_name}-dbt-daily-${var.environment}"
  description         = "Trigger DBT pipeline daily"
  schedule_expression = var.schedule_expression

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-dbt-daily-${var.environment}"
    }
  )
}

# EventBridge target - ECS task
resource "aws_cloudwatch_event_target" "dbt_daily" {
  count     = var.enable_scheduled_runs ? 1 : 0
  rule      = aws_cloudwatch_event_rule.dbt_daily[0].name
  target_id = "dbt-task"
  arn       = var.ecs_cluster_arn
  role_arn  = aws_iam_role.eventbridge_ecs[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.dbt.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [aws_security_group.dbt.id]
      assign_public_ip = false
    }
  }
}

# IAM role for EventBridge to trigger ECS tasks
resource "aws_iam_role" "eventbridge_ecs" {
  count = var.enable_scheduled_runs ? 1 : 0
  name  = "${var.project_name}-eventbridge-ecs-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for EventBridge to run ECS tasks
resource "aws_iam_role_policy" "eventbridge_ecs" {
  count = var.enable_scheduled_runs ? 1 : 0
  name  = "${var.project_name}-eventbridge-ecs-${var.environment}"
  role  = aws_iam_role.eventbridge_ecs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = aws_ecs_task_definition.dbt.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          var.task_execution_role_arn,
          var.task_role_arn
        ]
      }
    ]
  })
}

# CloudWatch Log Group for DBT (if separate from main ECS log group)
resource "aws_cloudwatch_log_group" "dbt" {
  count             = var.create_separate_log_group ? 1 : 0
  name              = "/ecs/${var.project_name}-dbt-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "/ecs/${var.project_name}-dbt-${var.environment}"
    }
  )
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
