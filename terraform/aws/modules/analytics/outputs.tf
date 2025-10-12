output "s3_bucket_name" {
  description = "Name of the S3 bucket for analytics data"
  value       = aws_s3_bucket.analytics.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for analytics data"
  value       = aws_s3_bucket.analytics.arn
}

output "security_group_id" {
  description = "Security group ID for DBT tasks"
  value       = aws_security_group.dbt.id
}

output "task_definition_arn" {
  description = "ARN of the DBT task definition"
  value       = aws_ecs_task_definition.dbt.arn
}

output "task_definition_family" {
  description = "Family of the DBT task definition"
  value       = aws_ecs_task_definition.dbt.family
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for scheduled runs"
  value       = var.enable_scheduled_runs ? aws_cloudwatch_event_rule.dbt_daily[0].arn : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for DBT"
  value       = var.create_separate_log_group ? aws_cloudwatch_log_group.dbt[0].name : var.log_group_name
}
