output "s3_bucket_name" {
  description = "Name of the S3 bucket for Airflow"
  value       = aws_s3_bucket.airflow.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Airflow"
  value       = aws_s3_bucket.airflow.arn
}

output "security_group_id" {
  description = "Security group ID for Airflow services"
  value       = aws_security_group.airflow.id
}

output "webserver_service_name" {
  description = "Name of the Airflow webserver ECS service"
  value       = aws_ecs_service.airflow_webserver.name
}

output "scheduler_service_name" {
  description = "Name of the Airflow scheduler ECS service"
  value       = aws_ecs_service.airflow_scheduler.name
}

output "worker_service_name" {
  description = "Name of the Airflow worker ECS service"
  value       = aws_ecs_service.airflow_worker.name
}

output "fernet_key_secret_arn" {
  description = "ARN of the Fernet key secret"
  value       = aws_secretsmanager_secret.airflow_fernet_key.arn
}

output "webserver_secret_arn" {
  description = "ARN of the webserver secret"
  value       = aws_secretsmanager_secret.airflow_webserver_secret.arn
}
