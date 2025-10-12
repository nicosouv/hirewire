# S3 Bucket for Airflow DAGs and logs
resource "aws_s3_bucket" "airflow" {
  bucket = "${var.project_name}-airflow-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-${var.environment}"
    }
  )
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "airflow" {
  bucket = aws_s3_bucket.airflow.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "airflow" {
  bucket = aws_s3_bucket.airflow.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "airflow" {
  bucket = aws_s3_bucket.airflow.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Secrets Manager for Airflow credentials
resource "aws_secretsmanager_secret" "airflow_fernet_key" {
  name        = "${var.project_name}/airflow/fernet-key-${var.environment}"
  description = "Airflow Fernet encryption key"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "airflow_fernet_key" {
  secret_id     = aws_secretsmanager_secret.airflow_fernet_key.id
  secret_string = var.fernet_key
}

resource "aws_secretsmanager_secret" "airflow_webserver_secret" {
  name        = "${var.project_name}/airflow/webserver-secret-${var.environment}"
  description = "Airflow webserver secret key"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "airflow_webserver_secret" {
  secret_id     = aws_secretsmanager_secret.airflow_webserver_secret.id
  secret_string = var.webserver_secret_key
}

# Security Group for Airflow services
resource "aws_security_group" "airflow" {
  name        = "${var.project_name}-airflow-sg-${var.environment}"
  description = "Security group for Airflow ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Allow access to Airflow webserver"
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
      Name = "${var.project_name}-airflow-sg-${var.environment}"
    }
  )
}

# Common environment variables for all Airflow services
locals {
  common_environment = [
    {
      name  = "AIRFLOW__CORE__EXECUTOR"
      value = "CeleryExecutor"
    },
    {
      name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
      value = "postgresql://${var.database_user}:${var.database_password}@${var.database_endpoint}/${var.database_name}"
    },
    {
      name  = "AIRFLOW__CELERY__BROKER_URL"
      value = var.redis_url
    },
    {
      name  = "AIRFLOW__CELERY__RESULT_BACKEND"
      value = "db+postgresql://${var.database_user}:${var.database_password}@${var.database_endpoint}/${var.database_name}"
    },
    {
      name  = "AIRFLOW__CORE__DAGS_FOLDER"
      value = "/opt/airflow/dags"
    },
    {
      name  = "AIRFLOW__CORE__LOAD_EXAMPLES"
      value = "False"
    },
    {
      name  = "AIRFLOW__API__AUTH_BACKENDS"
      value = "airflow.api.auth.backend.basic_auth"
    },
    {
      name  = "AIRFLOW__WEBSERVER__EXPOSE_CONFIG"
      value = "True"
    },
    {
      name  = "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION"
      value = "True"
    },
    {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  ]

  common_secrets = [
    {
      name      = "AIRFLOW__CORE__FERNET_KEY"
      valueFrom = aws_secretsmanager_secret.airflow_fernet_key.arn
    },
    {
      name      = "AIRFLOW__WEBSERVER__SECRET_KEY"
      valueFrom = aws_secretsmanager_secret.airflow_webserver_secret.arn
    }
  ]
}

# ECS Task Definition - Airflow Webserver
resource "aws_ecs_task_definition" "airflow_webserver" {
  family                   = "${var.project_name}-airflow-webserver-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.webserver_cpu
  memory                   = var.webserver_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "webserver"
      image     = var.airflow_image
      essential = true
      command   = ["webserver"]

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = local.common_environment
      secrets     = local.common_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "airflow-webserver"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-webserver-${var.environment}"
    }
  )
}

# ECS Service - Airflow Webserver
resource "aws_ecs_service" "airflow_webserver" {
  name            = "${var.project_name}-airflow-webserver-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_webserver.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = false
  }

  enable_execute_command = var.enable_ecs_exec

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-webserver-${var.environment}"
    }
  )
}

# ECS Task Definition - Airflow Scheduler
resource "aws_ecs_task_definition" "airflow_scheduler" {
  family                   = "${var.project_name}-airflow-scheduler-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.scheduler_cpu
  memory                   = var.scheduler_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "scheduler"
      image     = var.airflow_image
      essential = true
      command   = ["scheduler"]

      environment = local.common_environment
      secrets     = local.common_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "airflow-scheduler"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-scheduler-${var.environment}"
    }
  )
}

# ECS Service - Airflow Scheduler
resource "aws_ecs_service" "airflow_scheduler" {
  name            = "${var.project_name}-airflow-scheduler-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_scheduler.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = false
  }

  enable_execute_command = var.enable_ecs_exec

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-scheduler-${var.environment}"
    }
  )
}

# ECS Task Definition - Airflow Worker
resource "aws_ecs_task_definition" "airflow_worker" {
  family                   = "${var.project_name}-airflow-worker-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.airflow_image
      essential = true
      command   = ["celery", "worker"]

      environment = local.common_environment
      secrets     = local.common_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "airflow-worker"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-worker-${var.environment}"
    }
  )
}

# ECS Service - Airflow Worker
resource "aws_ecs_service" "airflow_worker" {
  name            = "${var.project_name}-airflow-worker-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_worker.arn
  desired_count   = var.worker_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = false
  }

  enable_execute_command = var.enable_ecs_exec

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-airflow-worker-${var.environment}"
    }
  )
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
