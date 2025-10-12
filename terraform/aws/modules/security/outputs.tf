output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.main.arn
}

output "database_security_group_id" {
  description = "Security group ID for database"
  value       = aws_security_group.database.id
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = var.create_redis_security_group ? aws_security_group.redis[0].id : null
}

output "s3_access_policy_arn" {
  description = "ARN of the S3 access policy"
  value       = aws_iam_policy.s3_access.arn
}

output "secrets_access_policy_arn" {
  description = "ARN of the Secrets Manager access policy"
  value       = aws_iam_policy.secrets_access.arn
}

output "kms_access_policy_arn" {
  description = "ARN of the KMS access policy"
  value       = aws_iam_policy.kms_access.arn
}

output "cloudwatch_logs_policy_arn" {
  description = "ARN of the CloudWatch Logs policy"
  value       = aws_iam_policy.cloudwatch_logs.arn
}

output "ecr_access_policy_arn" {
  description = "ARN of the ECR access policy"
  value       = aws_iam_policy.ecr_access.arn
}

output "database_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.database_password.arn
}

output "database_password_secret_name" {
  description = "Name of the database password secret"
  value       = aws_secretsmanager_secret.database_password.name
}
