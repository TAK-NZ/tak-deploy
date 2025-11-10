output "customer_name" {
  description = "Customer name"
  value       = var.customer_name
}

output "customer_url" {
  description = "Customer TAK server URL"
  value       = "https://${local.fqdn}"
}

output "fqdn" {
  description = "Fully qualified domain name"
  value       = local.fqdn
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager secret ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.main.arn
}
