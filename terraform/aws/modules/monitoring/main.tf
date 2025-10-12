# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts-${var.environment}"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-alerts-${var.environment}"
    }
  )
}

# SNS Topic Subscription (email)
resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # ECS CPU and Memory
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Cluster Metrics"
        }
      },
      # RDS Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            [".", "DatabaseConnections", { stat = "Sum" }],
            [".", "ReadLatency", { stat = "Average" }],
            [".", "WriteLatency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      },
      # ALB Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            [".", "TargetResponseTime", { stat = "Average" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      # CloudFront Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum" }],
            [".", "BytesDownloaded", { stat = "Sum" }],
            [".", "4xxErrorRate", { stat = "Average" }],
            [".", "5xxErrorRate", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront Metrics"
        }
      }
    ]
  })
}

# CloudWatch Alarm - ECS High CPU
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "${var.project_name}-ecs-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold
  alarm_description   = "ECS cluster CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# CloudWatch Alarm - ECS High Memory
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "${var.project_name}-ecs-high-memory-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold
  alarm_description   = "ECS cluster memory utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# CloudWatch Alarm - RDS High CPU
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  count               = var.rds_cluster_identifier != null ? 1 : 0
  alarm_name          = "${var.project_name}-rds-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_identifier
  }

  tags = var.tags
}

# CloudWatch Alarm - RDS High Connections
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  count               = var.rds_cluster_identifier != null ? 1 : 0
  alarm_name          = "${var.project_name}-rds-high-connections-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  alarm_description   = "RDS connection count is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_identifier
  }

  tags = var.tags
}

# CloudWatch Alarm - ALB High Response Time
resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  count               = var.alb_arn != null ? 1 : 0
  alarm_name          = "${var.project_name}-alb-high-response-time-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold
  alarm_description   = "ALB response time is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# CloudWatch Alarm - ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count               = var.alb_arn != null ? 1 : 0
  alarm_name          = "${var.project_name}-alb-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_description   = "ALB 5xx error count is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# AWS Budget
resource "aws_budgets_budget" "monthly" {
  name              = "${var.project_name}-monthly-budget-${var.environment}"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_budget_limit)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != null ? [var.budget_alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != null ? [var.budget_alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_email != null ? [var.budget_alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }
}

# CloudWatch Log Metric Filter - Application Errors
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  count          = var.log_group_name != null ? 1 : 0
  name           = "${var.project_name}-application-errors-${var.environment}"
  log_group_name = var.log_group_name
  pattern        = "[ERROR]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# CloudWatch Alarm - Application Errors
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  count               = var.log_group_name != null ? 1 : 0
  alarm_name          = "${var.project_name}-application-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApplicationErrors"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = var.application_errors_threshold
  alarm_description   = "Application error count is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}
