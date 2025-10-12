output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.api.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.api.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.api.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.api.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.api.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.api.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.api.arn
}

output "security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = var.certificate_arn != null ? "https://${aws_lb.api.dns_name}" : "http://${aws_lb.api.dns_name}"
}
